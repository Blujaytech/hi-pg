package com.pgplatform.owner.importer;

import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import static org.assertj.core.api.Assertions.assertThat;

class PgExcelImportParserTest {
    private final PgExcelImportParser parser = new PgExcelImportParser();

    @Test
    void parsesMasterSheetWithoutPublishingAnything() throws Exception {
        byte[] workbook = workbook("""
                <row r="1">
                  <c r="A1" t="inlineStr"><is><t>PG Name</t></is></c>
                  <c r="B1" t="inlineStr"><is><t>Owner Mobile</t></is></c>
                  <c r="C1" t="inlineStr"><is><t>Street / Area Address</t></is></c>
                  <c r="D1" t="inlineStr"><is><t>City</t></is></c>
                  <c r="E1" t="inlineStr"><is><t>Stay Type</t></is></c>
                </row>
                <row r="2">
                  <c r="A2" t="inlineStr"><is><t>Test Stay</t></is></c>
                  <c r="B2"><v>9876543210</v></c>
                  <c r="C2" t="inlineStr"><is><t>1 Test Road</t></is></c>
                  <c r="D2" t="inlineStr"><is><t>Bangalore</t></is></c>
                  <c r="E2" t="inlineStr"><is><t>Women</t></is></c>
                </row>
                """);

        var parsed = parser.parse(workbook, List.of());

        assertThat(parsed.sheetName()).isEqualTo("MASTER_DATA");
        assertThat(parsed.rows()).hasSize(1);
        assertThat(parsed.rows().get(0).city()).isEqualTo("Bengaluru");
        assertThat(parsed.rows().get(0).ownerMobile()).isEqualTo("+919876543210");
        assertThat(parsed.rows().get(0).validationStatus()).isEqualTo(PgImportValidationStatus.WARNING);
    }

    @Test
    void parsesUniquePgListLocationAliasAndEmbeddedPhoto() throws Exception {
        byte[] workbook = uniquePgWorkbook();

        var parsed = parser.parse(workbook, List.of());

        assertThat(parsed.sheetName()).isEqualTo("Unique PG List");
        assertThat(parsed.rows()).singleElement().satisfies(row -> {
            assertThat(row.locationUrl()).isEqualTo("https://www.google.com/maps/search/?api=1&query=Test+Stay");
            assertThat(row.genderPreference()).isEqualTo(com.pgplatform.owner.GenderPreference.CO_ED);
            assertThat(row.photos()).singleElement().satisfies(photo -> {
                assertThat(photo.fileName()).isEqualTo("image1.jpeg");
                assertThat(photo.contentType()).isEqualTo("image/jpeg");
                assertThat(photo.content()).containsExactly((byte) 0xff, (byte) 0xd8, (byte) 0xff, 0x01);
            });
        });
    }

    @Test
    void keepsGenericPlaceholderImagesAsPgPhotos() throws Exception {
        var parsed = parser.parse(uniquePgWorkbook("Generic placeholder"), List.of());

        assertThat(parsed.rows()).singleElement().satisfies(row -> {
            assertThat(row.photos()).hasSize(1);
            assertThat(row.validationMessages()).doesNotContain("Generic placeholder image was skipped");
        });
    }

    @Test
    void parsesLocalSamplesWhenPathsAreProvided() throws Exception {
        String paths = System.getProperty("pg.import.samples", "");
        if (paths.isBlank()) return;
        String[] samples = paths.split(";");
        int totalRows = 0;
        int validMobiles = 0;
        for (String value : samples) {
            var parsed = parser.parse(Files.readAllBytes(Path.of(value)), List.of());
            assertThat(parsed.rows()).as(value).isNotEmpty();
            totalRows += parsed.rows().size();
            int workbookMobiles = (int) parsed.rows().stream().filter(row -> row.ownerMobile() != null).count();
            validMobiles += workbookMobiles;
            if (Path.of(value).getFileName().toString().equals("HI_PG_HYDERABAD_407_.xlsx")) {
                assertThat(parsed.sheetName()).isEqualTo("Unique PG List");
                assertThat(parsed.rows()).hasSize(406);
                assertThat(parsed.rows()).allSatisfy(row -> assertThat(row.locationUrl()).isNotBlank());
                assertThat(parsed.rows().stream().mapToInt(row -> row.photos().size()).sum()).isEqualTo(407);
                assertThat(workbookMobiles).isEqualTo(284);
                assertThat(parsed.rows()).filteredOn(row -> row.sourceRowNumber() == 152).singleElement()
                        .extracting(row -> row.genderPreference())
                        .isEqualTo(com.pgplatform.owner.GenderPreference.CO_ED);
            }
        }
        if (samples.length == 5) {
            assertThat(totalRows).isEqualTo(1171);
            assertThat(validMobiles).isEqualTo(647);
        }
    }

    private byte[] uniquePgWorkbook() throws Exception {
        return uniquePgWorkbook("Embedded image");
    }

    private byte[] uniquePgWorkbook(String imageMarker) throws Exception {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(bytes)) {
            entry(zip, "xl/workbook.xml", """
                    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                      xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
                      <sheets><sheet name="Unique PG List" sheetId="1" r:id="rId1"/></sheets>
                    </workbook>
                    """);
            entry(zip, "xl/_rels/workbook.xml.rels", """
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId1" Type="worksheet" Target="worksheets/sheet1.xml"/>
                    </Relationships>
                    """);
            entry(zip, "xl/worksheets/sheet1.xml", """
                    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                      xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
                      <sheetData>
                        <row r="1">
                          <c r="A1" t="inlineStr"><is><t>PG Name</t></is></c>
                          <c r="B1" t="inlineStr"><is><t>Street / Area Address</t></is></c>
                          <c r="C1" t="inlineStr"><is><t>City</t></is></c>
                          <c r="D1" t="inlineStr"><is><t>Stay Type</t></is></c>
                          <c r="E1" t="inlineStr"><is><t>Location URL</t></is></c>
                          <c r="F1" t="inlineStr"><is><t>PG Image</t></is></c>
                        </row>
                        <row r="2">
                          <c r="A2" t="inlineStr"><is><t>Test Stay</t></is></c>
                          <c r="B2" t="inlineStr"><is><t>1 Test Road</t></is></c>
                          <c r="C2" t="inlineStr"><is><t>Hyderabad</t></is></c>
                          <c r="D2" t="inlineStr"><is><t>Men &amp; Women (separate buildings)</t></is></c>
                          <c r="E2" t="inlineStr"><is><t>https://www.google.com/maps/search/?api=1&amp;query=Test+Stay</t></is></c>
                          <c r="F2" t="inlineStr"><is><t>%s</t></is></c>
                        </row>
                      </sheetData>
                      <drawing r:id="rId2"/>
                    </worksheet>
                    """.formatted(imageMarker));
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
                        <xdr:from><xdr:col>5</xdr:col><xdr:row>1</xdr:row></xdr:from>
                        <xdr:pic><xdr:blipFill><a:blip r:embed="rId1"/></xdr:blipFill></xdr:pic>
                        <xdr:to><xdr:col>6</xdr:col><xdr:row>2</xdr:row></xdr:to>
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

    private byte[] workbook(String rows) throws Exception {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ZipOutputStream zip = new ZipOutputStream(bytes)) {
            entry(zip, "xl/workbook.xml", """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                      xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
                      <sheets><sheet name="MASTER_DATA" sheetId="1" r:id="rId1"/></sheets>
                    </workbook>
                    """);
            entry(zip, "xl/_rels/workbook.xml.rels", """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
                    </Relationships>
                    """);
            entry(zip, "xl/worksheets/sheet1.xml", """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
                      <sheetData>%s</sheetData>
                    </worksheet>
                    """.formatted(rows));
        }
        return bytes.toByteArray();
    }

    private void entry(ZipOutputStream zip, String name, String content) throws Exception {
        zip.putNextEntry(new ZipEntry(name));
        zip.write(content.getBytes(StandardCharsets.UTF_8));
        zip.closeEntry();
    }
}
