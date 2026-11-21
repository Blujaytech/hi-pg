package com.pgplatform.owner.importer;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.document.DocumentStorageGateway;
import com.pgplatform.document.DocumentStorageException;
import com.pgplatform.owner.PgOwnerContactRepository;
import com.pgplatform.owner.PgPhotoRepository;
import com.pgplatform.owner.PgRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.boot.test.mock.mockito.MockBean;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

class PgImportServiceTest extends AbstractIntegrationTest {
    @Autowired private PgImportService service;
    @Autowired private PgRepository pgRepository;
    @Autowired private PgPhotoRepository pgPhotoRepository;
    @Autowired private PgImportPhotoRepository importPhotoRepository;
    @Autowired private PgImportRowRepository importRowRepository;
    @Autowired private PgOwnerContactRepository contactRepository;
    @MockBean private DocumentStorageGateway storageGateway;

    @Test
    void uploadStagesOnlyAndConfirmationPublishesOnce() throws Exception {
        when(storageGateway.store(any(byte[].class), anyString(), anyString()))
                .thenReturn("private/documents/imported/test.jpg");
        MockMultipartFile file = new MockMultipartFile(
                "file", "master.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                workbook());

        var preview = service.upload(file);

        assertThat(preview.publishableRows()).isEqualTo(1);
        assertThat(preview.validMobileRows()).isEqualTo(1);
        assertThat(preview.rows()).singleElement().extracting(row -> row.imageCount()).isEqualTo(1);
        assertThat(pgRepository.count()).isZero();
        assertThat(pgPhotoRepository.count()).isZero();
        assertThat(importPhotoRepository.count()).isEqualTo(1);
        assertThat(contactRepository.count()).isZero();

        var completed = service.publishAndInvite(preview.id());
        var repeated = service.publishAndInvite(preview.id());

        assertThat(completed.publishedRows()).isEqualTo(1);
        assertThat(repeated.publishedRows()).isEqualTo(1);
        assertThat(pgRepository.count()).isEqualTo(1);
        assertThat(pgPhotoRepository.findAll()).singleElement().satisfies(photo -> {
            assertThat(photo.isCover()).isTrue();
            assertThat(photo.getOriginalFileName()).isEqualTo("image1.jpeg");
            assertThat(photo.getStorageKey()).isEqualTo("private/documents/imported/test.jpg");
        });
        assertThat(pgRepository.findAll()).singleElement()
                .extracting(pg -> pg.getPhotoStorageKey()).isEqualTo("private/documents/imported/test.jpg");
        assertThat(contactRepository.findAll()).singleElement()
                .extracting(contact -> contact.getNormalizedMobile()).isEqualTo("+919876543210");
    }

    @Test
    void stagesProvidedWorkbookWithAllLocationsAndRealImages() throws Exception {
        String sample = System.getProperty("pg.import.sample", "");
        if (sample.isBlank()) return;
        Path path = Path.of(sample);
        MockMultipartFile file = new MockMultipartFile(
                "file", path.getFileName().toString(),
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                Files.readAllBytes(path));

        var preview = service.upload(file);

        assertThat(preview.sourceSheet()).isEqualTo("Unique PG List");
        assertThat(preview.totalRows()).isEqualTo(406);
        assertThat(preview.publishableRows()).isEqualTo(406);
        assertThat(preview.validMobileRows()).isEqualTo(284);
        assertThat(preview.rows()).allSatisfy(row -> assertThat(row.locationUrl()).isNotBlank());
        assertThat(preview.rows().stream().mapToInt(row -> row.imageCount()).sum()).isEqualTo(407);
        assertThat(importPhotoRepository.count()).isEqualTo(407);
        assertThat(pgRepository.count()).isZero();
        assertThat(pgPhotoRepository.count()).isZero();
    }

    @Test
    void reuploadRepairsMissingPhotosOnPublishedListings() throws Exception {
        when(storageGateway.store(any(byte[].class), anyString(), anyString()))
                .thenReturn("private/documents/imported/repaired.jpg");
        MockMultipartFile file = new MockMultipartFile(
                "file", "repair.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                workbook());
        var preview = service.upload(file);
        importPhotoRepository.deleteAll();
        importPhotoRepository.flush();
        PgImportRow row = importRowRepository.findAll().get(0);
        row.setImageCount(0);
        importRowRepository.saveAndFlush(row);
        service.publishAndInvite(preview.id());

        var repaired = service.upload(file);

        assertThat(repaired.rows()).singleElement().extracting(value -> value.imageCount()).isEqualTo(1);
        assertThat(importPhotoRepository.count()).isEqualTo(1);
        assertThat(pgPhotoRepository.count()).isEqualTo(1);
        assertThat(pgRepository.findAll()).singleElement()
                .extracting(pg -> pg.getPhotoStorageKey()).isEqualTo("private/documents/imported/repaired.jpg");
    }

    @Test
    void publishesListingsAndDatabaseBackedPhotosWhenObjectStorageIsUnavailable() throws Exception {
        when(storageGateway.store(any(byte[].class), anyString(), anyString()))
                .thenThrow(new DocumentStorageException("storage unavailable", new RuntimeException("denied")));
        MockMultipartFile file = new MockMultipartFile(
                "file", "fallback.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                workbook());

        var preview = service.upload(file);
        var completed = service.publishAndInvite(preview.id());

        assertThat(completed.publishedRows()).isEqualTo(1);
        assertThat(pgRepository.count()).isEqualTo(1);
        assertThat(pgPhotoRepository.findAll()).singleElement().satisfies(photo -> {
            assertThat(photo.getStorageKey()).startsWith("database://pg-photo/");
            assertThat(photo.getContent()).isNotEmpty();
        });
    }

    private byte[] workbook() throws Exception {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(bytes)) {
            entry(zip, "xl/workbook.xml", """
                    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                      xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
                      <sheets><sheet name="MASTER_DATA" sheetId="1" r:id="rId1"/></sheets>
                    </workbook>
                    """);
            entry(zip, "xl/_rels/workbook.xml.rels", """
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId1" Type="worksheet" Target="worksheets/sheet1.xml"/>
                    </Relationships>
                    """);
            entry(zip, "xl/worksheets/sheet1.xml", """
                    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                      xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheetData>
                      <row r="1">
                        <c r="A1" t="inlineStr"><is><t>PG Name</t></is></c>
                        <c r="B1" t="inlineStr"><is><t>Owner Name</t></is></c>
                        <c r="C1" t="inlineStr"><is><t>Owner Mobile</t></is></c>
                        <c r="D1" t="inlineStr"><is><t>Street / Area Address</t></is></c>
                        <c r="E1" t="inlineStr"><is><t>City</t></is></c>
                        <c r="F1" t="inlineStr"><is><t>Stay Type</t></is></c>
                        <c r="G1" t="inlineStr"><is><t>PG Image</t></is></c>
                      </row>
                      <row r="2">
                        <c r="A2" t="inlineStr"><is><t>Integration Stay</t></is></c>
                        <c r="B2" t="inlineStr"><is><t>Test Owner</t></is></c>
                        <c r="C2"><v>9876543210</v></c>
                        <c r="D2" t="inlineStr"><is><t>1 Test Road</t></is></c>
                        <c r="E2" t="inlineStr"><is><t>Pune</t></is></c>
                        <c r="F2" t="inlineStr"><is><t>Co-Living</t></is></c>
                        <c r="G2" t="inlineStr"><is><t>Embedded image</t></is></c>
                      </row>
                    </sheetData><drawing r:id="rId2"/></worksheet>
                    """);
            entry(zip, "xl/worksheets/_rels/sheet1.xml.rels", """
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId2" Type="drawing" Target="../drawings/drawing1.xml"/>
                    </Relationships>
                    """);
            entry(zip, "xl/drawings/drawing1.xml", """
                    <xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing"
                      xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                      xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
                      <xdr:twoCellAnchor>
                        <xdr:from><xdr:col>6</xdr:col><xdr:row>1</xdr:row></xdr:from>
                        <xdr:pic><xdr:blipFill><a:blip r:embed="rId1"/></xdr:blipFill></xdr:pic>
                        <xdr:to><xdr:col>7</xdr:col><xdr:row>2</xdr:row></xdr:to>
                      </xdr:twoCellAnchor>
                    </xdr:wsDr>
                    """);
            entry(zip, "xl/drawings/_rels/drawing1.xml.rels", """
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId1" Type="image" Target="../media/image1.jpeg"/>
                    </Relationships>
                    """);
            zip.putNextEntry(new ZipEntry("xl/media/image1.jpeg"));
            zip.write(new byte[]{(byte) 0xff, (byte) 0xd8, (byte) 0xff, 0x01});
            zip.closeEntry();
        }
        return bytes.toByteArray();
    }

    private void entry(ZipOutputStream zip, String name, String content) throws Exception {
        zip.putNextEntry(new ZipEntry(name));
        zip.write(content.getBytes(StandardCharsets.UTF_8));
        zip.closeEntry();
    }
}
