package com.pgplatform.owner.importer;

import com.pgplatform.common.NotFoundException;
import com.pgplatform.document.DocumentStorageGateway;
import com.pgplatform.document.DocumentStorageException;
import com.pgplatform.owner.AdminPgListingService;
import com.pgplatform.owner.LocationUrls;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgClaimStatus;
import com.pgplatform.owner.PgInvitationStatus;
import com.pgplatform.owner.PgOwnerContact;
import com.pgplatform.owner.PgPhoto;
import com.pgplatform.owner.PgPhotoRepository;
import com.pgplatform.owner.PgPhotoUrls;
import com.pgplatform.owner.PgRepository;
import com.pgplatform.owner.PgStatus;
import com.pgplatform.owner.PgVerificationStatus;
import com.pgplatform.owner.importer.dto.PgImportBatchResponse;
import com.pgplatform.owner.importer.dto.PgImportRowLocationRequest;
import com.pgplatform.owner.importer.dto.PgImportRowResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

import java.security.MessageDigest;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@Service
public class PgImportService {
    private final PgImportBatchRepository batchRepository;
    private final PgImportRowRepository rowRepository;
    private final PgImportPhotoRepository importPhotoRepository;
    private final PgRepository pgRepository;
    private final PgPhotoRepository pgPhotoRepository;
    private final DocumentStorageGateway storageGateway;
    private final AdminPgListingService listingService;
    private final PgExcelImportParser parser;

    public PgImportService(PgImportBatchRepository batchRepository, PgImportRowRepository rowRepository,
                           PgImportPhotoRepository importPhotoRepository, PgRepository pgRepository,
                           PgPhotoRepository pgPhotoRepository, DocumentStorageGateway storageGateway,
                           AdminPgListingService listingService, PgExcelImportParser parser) {
        this.batchRepository = batchRepository;
        this.rowRepository = rowRepository;
        this.importPhotoRepository = importPhotoRepository;
        this.pgRepository = pgRepository;
        this.pgPhotoRepository = pgPhotoRepository;
        this.storageGateway = storageGateway;
        this.listingService = listingService;
        this.parser = parser;
    }

    @Transactional
    public PgImportBatchResponse upload(MultipartFile file) {
        String fileName = file.getOriginalFilename() == null ? "import.xlsx" : file.getOriginalFilename().trim();
        if (!fileName.toLowerCase().endsWith(".xlsx")) throw new IllegalArgumentException("Choose an .xlsx Excel file");
        byte[] content;
        try {
            content = file.getBytes();
        } catch (Exception error) {
            throw new IllegalArgumentException("The Excel file could not be read");
        }
        String hash = sha256(content);
        PgImportBatch existing = batchRepository.findByFileSha256AndDeletedAtIsNull(hash).orElse(null);
        if (existing != null) return refreshPhotos(existing, content);

        PgExcelImportParser.ParsedWorkbook parsed = parser.parse(content,
                pgRepository.findAllByDeletedAtIsNullOrderByCreatedAtDesc());
        PgImportBatch batch = new PgImportBatch();
        batch.setFileName(limit(fileName, 255));
        batch.setFileSha256(hash);
        batch.setSourceSheet(limit(parsed.sheetName(), 255));
        batch.setStatus(PgImportBatchStatus.PREVIEW_READY);
        batch.setTotalRows(parsed.rows().size());
        batch.setPublishableRows((int) parsed.rows().stream().filter(this::publishable).count());
        batch.setWarningRows((int) parsed.rows().stream()
                .filter(row -> row.validationStatus() == PgImportValidationStatus.WARNING).count());
        batch.setInvalidRows((int) parsed.rows().stream()
                .filter(row -> row.validationStatus() == PgImportValidationStatus.INVALID).count());
        batch.setDuplicateRows((int) parsed.rows().stream()
                .filter(row -> row.validationStatus() == PgImportValidationStatus.DUPLICATE).count());
        batch.setValidMobileRows((int) parsed.rows().stream()
                .filter(this::publishable).filter(row -> row.ownerMobile() != null).count());
        batch = batchRepository.save(batch);

        List<PgImportRow> entities = new ArrayList<>();
        for (PgExcelImportParser.ParsedRow parsedRow : parsed.rows()) entities.add(entity(batch, parsedRow));
        entities = rowRepository.saveAll(entities);
        List<PgImportPhoto> photos = new ArrayList<>();
        for (int index = 0; index < parsed.rows().size(); index++) {
            PgImportRow row = entities.get(index);
            List<PgExcelImportParser.ParsedPhoto> parsedPhotos = parsed.rows().get(index).photos();
            for (int photoIndex = 0; photoIndex < parsedPhotos.size(); photoIndex++) {
                photos.add(photo(row, parsedPhotos.get(photoIndex), photoIndex));
            }
        }
        if (!photos.isEmpty()) importPhotoRepository.saveAll(photos);
        return response(batch, entities);
    }

    private PgImportBatchResponse refreshPhotos(PgImportBatch batch, byte[] content) {
        PgExcelImportParser.ParsedWorkbook parsed = parser.parse(content, List.of());
        Map<Integer, PgExcelImportParser.ParsedRow> parsedByRow = new LinkedHashMap<>();
        parsed.rows().forEach(row -> parsedByRow.put(row.sourceRowNumber(), row));
        List<PgImportRow> existingRows = rows(batch.getId());
        Map<UUID, List<PgImportPhoto>> existingPhotos = importPhotos(existingRows);
        List<PgImportPhoto> additions = new ArrayList<>();

        for (PgImportRow row : existingRows) {
            PgExcelImportParser.ParsedRow parsedRow = parsedByRow.get(row.getSourceRowNumber());
            if (parsedRow == null) continue;
            Set<Integer> existingOrders = existingPhotos.getOrDefault(row.getId(), List.of()).stream()
                    .map(PgImportPhoto::getDisplayOrder).collect(java.util.stream.Collectors.toSet());
            for (int index = 0; index < parsedRow.photos().size(); index++) {
                if (!existingOrders.contains(index)) additions.add(photo(row, parsedRow.photos().get(index), index));
            }
            row.setImageCount(parsedRow.photos().size());
            row.setValidationMessages(String.join("\n", parsedRow.validationMessages()));
        }
        rowRepository.saveAll(existingRows);
        if (!additions.isEmpty()) importPhotoRepository.saveAll(additions);

        if (batch.getStatus() == PgImportBatchStatus.COMPLETED) {
            List<PgImportPhoto> publishedAdditions = additions.stream()
                    .filter(photo -> photo.getImportRow().getPublishedPg() != null).toList();
            storePhotos(publishedAdditions);
            Map<Pg, List<PgImportPhoto>> additionsByPg = new LinkedHashMap<>();
            publishedAdditions.forEach(photo -> additionsByPg
                    .computeIfAbsent(photo.getImportRow().getPublishedPg(), ignored -> new ArrayList<>()).add(photo));
            additionsByPg.forEach(this::publishPhotos);
        }
        return response(batch, existingRows);
    }

    @Transactional(readOnly = true)
    public List<PgImportBatchResponse> list() {
        return batchRepository.findAllByDeletedAtIsNullOrderByCreatedAtDesc().stream()
                .map(batch -> response(batch, List.of())).toList();
    }

    @Transactional(readOnly = true)
    public PgImportBatchResponse get(UUID batchId) {
        PgImportBatch batch = batchRepository.findById(batchId)
                .filter(value -> value.getDeletedAt() == null)
                .orElseThrow(() -> new NotFoundException("PG import batch not found"));
        return response(batch, rows(batchId));
    }

    @Transactional
    public PgImportBatchResponse updateLocation(UUID batchId, UUID rowId, PgImportRowLocationRequest request) {
        PgImportRow row = rowRepository.findById(rowId)
                .filter(value -> value.getDeletedAt() == null && value.getBatch().getId().equals(batchId))
                .orElseThrow(() -> new NotFoundException("PG import row not found"));
        if (row.getPublishStatus() == PgImportPublishStatus.PUBLISHED) {
            throw new IllegalArgumentException("A published import row can no longer be edited here");
        }
        if ((request.latitude() == null) != (request.longitude() == null)) {
            throw new IllegalArgumentException("Provide both latitude and longitude, or leave both empty");
        }
        row.setLatitude(request.latitude());
        row.setLongitude(request.longitude());
        row.setLocationUrl(LocationUrls.normalizeGoogleMapsUrl(request.locationUrl()));
        rowRepository.save(row);
        return get(batchId);
    }

    @Transactional
    public PgImportBatchResponse publishAndInvite(UUID batchId) {
        PgImportBatch batch = batchRepository.findLockedByIdAndDeletedAtIsNull(batchId)
                .orElseThrow(() -> new NotFoundException("PG import batch not found"));
        List<PgImportRow> rows = rows(batchId);
        if (batch.getStatus() == PgImportBatchStatus.COMPLETED) return response(batch, rows);
        batch.setStatus(PgImportBatchStatus.PUBLISHING);
        batchRepository.save(batch);

        Map<UUID, List<PgImportPhoto>> photosByRow = importPhotos(rows);

        Set<String> existingKeys = new HashSet<>();
        for (Pg pg : pgRepository.findAllByDeletedAtIsNullOrderByCreatedAtDesc()) {
            existingKeys.add(PgExcelImportParser.dedupeKey(pg.getName(), pg.getAddress(), pg.getCity()));
        }
        List<PgImportRow> rowsToPublish = new ArrayList<>();
        int skipped = 0;
        for (PgImportRow row : rows) {
            if (row.getPublishStatus() == PgImportPublishStatus.PUBLISHED) continue;
            if (!publishable(row.getValidationStatus()) || existingKeys.contains(row.getDedupeKey())) {
                row.setPublishStatus(PgImportPublishStatus.SKIPPED);
                skipped++;
            } else {
                rowsToPublish.add(row);
                existingKeys.add(row.getDedupeKey());
            }
        }
        try {
            storePhotos(rowsToPublish.stream()
                    .flatMap(row -> photosByRow.getOrDefault(row.getId(), List.of()).stream()).toList());
        } catch (DocumentStorageException ignored) {
            // Embedded Excel photos are already staged in Postgres. Publish
            // them from there instead of failing every listing when the
            // external object store is temporarily unavailable.
        }

        int published = batch.getPublishedRows();
        int invited = batch.getInvitedRows();
        for (PgImportRow row : rowsToPublish) {
            Pg pg = createListing(row);
            publishPhotos(pg, photosByRow.getOrDefault(row.getId(), List.of()));
            row.setPublishedPg(pg);
            row.setPublishStatus(PgImportPublishStatus.PUBLISHED);
            published++;
            PgOwnerContact contact = listingService.saveContact(pg, row.getOwnerName(), row.getOwnerMobile());
            PgInvitationStatus invitationStatus = listingService.invite(pg, contact);
            row.setInvitationStatus(invitationStatus);
            if (invitationStatus == PgInvitationStatus.SENT) invited++;
        }
        rowRepository.saveAll(rows);
        batch.setPublishedRows(published);
        batch.setInvitedRows(invited);
        batch.setSkippedRows(skipped);
        batch.setStatus(PgImportBatchStatus.COMPLETED);
        batch.setCompletedAt(Instant.now());
        return response(batchRepository.save(batch), rows);
    }

    private Pg createListing(PgImportRow row) {
        Pg pg = new Pg();
        pg.setName(row.getName());
        pg.setAddress(row.getAddress());
        pg.setCity(row.getCity());
        pg.setState(row.getState());
        pg.setPincode(row.getPincode());
        pg.setLatitude(row.getLatitude());
        pg.setLongitude(row.getLongitude());
        pg.setLocationUrl(row.getLocationUrl());
        pg.setDescription(row.getProperLocality());
        pg.setGenderPreference(row.getGenderPreference());
        pg.setOwner(null);
        pg.setAdminCreated(true);
        pg.setClaimStatus(PgClaimStatus.UNCLAIMED);
        pg.setVerificationStatus(PgVerificationStatus.UNVERIFIED);
        pg.setBookingEnabled(false);
        pg.setStatus(PgStatus.ACTIVE);
        return pgRepository.save(pg);
    }

    private PgImportRow entity(PgImportBatch batch, PgExcelImportParser.ParsedRow parsed) {
        PgImportRow row = new PgImportRow();
        row.setBatch(batch);
        row.setSourceRowNumber(parsed.sourceRowNumber());
        row.setName(parsed.name());
        row.setOwnerName(parsed.ownerName());
        row.setOwnerMobile(parsed.ownerMobile());
        row.setAddress(parsed.address());
        row.setCity(parsed.city());
        row.setState(parsed.state());
        row.setPincode(parsed.pincode());
        row.setLatitude(parsed.latitude());
        row.setLongitude(parsed.longitude());
        row.setLocationUrl(parsed.locationUrl());
        row.setProperLocality(parsed.properLocality());
        row.setOriginalStayType(parsed.originalStayType());
        row.setImageCount(parsed.photos().size());
        row.setGenderPreference(parsed.genderPreference());
        row.setValidationStatus(parsed.validationStatus());
        row.setValidationMessages(String.join("\n", parsed.validationMessages()));
        row.setDedupeKey(parsed.dedupeKey());
        return row;
    }

    private PgImportPhoto photo(PgImportRow row, PgExcelImportParser.ParsedPhoto parsed, int displayOrder) {
        PgImportPhoto photo = new PgImportPhoto();
        photo.setImportRow(row);
        photo.setOriginalFileName(limit(parsed.fileName(), 255));
        photo.setContentType(parsed.contentType());
        photo.setFileSize(parsed.content().length);
        photo.setDisplayOrder(displayOrder);
        photo.setContent(parsed.content());
        return photo;
    }

    private Map<UUID, List<PgImportPhoto>> importPhotos(List<PgImportRow> rows) {
        if (rows.isEmpty()) return Map.of();
        Map<UUID, List<PgImportPhoto>> result = new LinkedHashMap<>();
        importPhotoRepository.findAllByImportRowIdInAndDeletedAtIsNullOrderByImportRowSourceRowNumberAscDisplayOrderAsc(
                        rows.stream().map(PgImportRow::getId).toList())
                .forEach(photo -> result.computeIfAbsent(photo.getImportRow().getId(), ignored -> new ArrayList<>())
                        .add(photo));
        return result;
    }

    private void publishPhotos(Pg pg, List<PgImportPhoto> importedPhotos) {
        List<PgPhoto> photos = new ArrayList<>();
        for (PgImportPhoto imported : importedPhotos) {
            if (imported.getStorageKey() == null && imported.getContent() == null) continue;
            PgPhoto photo = new PgPhoto();
            photo.setPg(pg);
            photo.setStorageKey(imported.getStorageKey() == null
                    ? PgPhotoUrls.databaseStorageKey() : imported.getStorageKey());
            photo.setContent(imported.getStorageKey() == null ? imported.getContent() : null);
            photo.setOriginalFileName(imported.getOriginalFileName());
            photo.setContentType(imported.getContentType());
            photo.setFileSize(imported.getFileSize());
            photo.setDisplayOrder(imported.getDisplayOrder());
            photo.setCover(imported.getDisplayOrder() == 0);
            photos.add(photo);
        }
        if (photos.isEmpty()) return;
        photos = pgPhotoRepository.saveAll(photos);
        pg.setPhotoStorageKey(photos.get(0).getStorageKey());
        pgRepository.save(pg);
        importPhotoRepository.saveAll(importedPhotos);
    }

    private void storePhotos(List<PgImportPhoto> photos) {
        List<PgImportPhoto> pending = photos.stream()
                .filter(photo -> photo.getStorageKey() == null && photo.getContent() != null)
                .toList();
        if (pending.isEmpty()) return;
        ExecutorService executor = Executors.newFixedThreadPool(Math.min(8, pending.size()));
        List<CompletableFuture<StoredPhoto>> futures = pending.stream()
                .map(photo -> CompletableFuture.supplyAsync(() -> new StoredPhoto(photo,
                        storageGateway.store(photo.getContent(),
                                "excel-row-" + photo.getImportRow().getSourceRowNumber() + "-"
                                        + photo.getOriginalFileName(),
                                photo.getContentType())), executor))
                .toList();
        List<StoredPhoto> stored;
        try {
            CompletableFuture.allOf(futures.toArray(CompletableFuture[]::new)).join();
            stored = futures.stream().map(CompletableFuture::join).toList();
        } catch (CompletionException error) {
            futures.stream().filter(future -> future.isDone() && !future.isCompletedExceptionally())
                    .map(CompletableFuture::join).forEach(value -> deleteQuietly(value.storageKey()));
            Throwable cause = error.getCause();
            if (cause instanceof RuntimeException runtimeException) throw runtimeException;
            throw error;
        } finally {
            executor.shutdownNow();
        }
        stored.forEach(value -> {
            value.photo().setStorageKey(value.storageKey());
            value.photo().setContent(null);
        });
        importPhotoRepository.saveAll(stored.stream().map(StoredPhoto::photo).toList());
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            List<String> storageKeys = stored.stream().map(StoredPhoto::storageKey).toList();
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCompletion(int status) {
                    if (status == STATUS_ROLLED_BACK) storageKeys.forEach(PgImportService.this::deleteQuietly);
                }
            });
        }
    }

    private void deleteQuietly(String storageKey) {
        try {
            storageGateway.delete(storageKey);
        } catch (RuntimeException ignored) { }
    }

    private PgImportBatchResponse response(PgImportBatch batch, List<PgImportRow> rows) {
        return new PgImportBatchResponse(batch.getId(), batch.getFileName(), batch.getSourceSheet(), batch.getStatus(),
                batch.getTotalRows(), batch.getPublishableRows(), batch.getWarningRows(), batch.getInvalidRows(),
                batch.getDuplicateRows(), batch.getValidMobileRows(), batch.getPublishedRows(), batch.getInvitedRows(),
                batch.getSkippedRows(), batch.getCreatedAt(), batch.getCompletedAt(), rows.stream().map(this::response).toList());
    }

    private PgImportRowResponse response(PgImportRow row) {
        List<String> messages = row.getValidationMessages() == null || row.getValidationMessages().isBlank()
                ? List.of() : List.of(row.getValidationMessages().split("\n"));
        return new PgImportRowResponse(row.getId(), row.getSourceRowNumber(), row.getName(), row.getOwnerName(),
                row.getOwnerMobile(), row.getAddress(), row.getCity(), row.getState(), row.getPincode(),
                row.getLatitude(), row.getLongitude(), row.getLocationUrl(), row.getProperLocality(),
                row.getOriginalStayType(), row.getGenderPreference(), row.getImageCount(), row.getValidationStatus(), messages,
                row.getPublishStatus(), row.getInvitationStatus(),
                row.getPublishedPg() == null ? null : row.getPublishedPg().getId());
    }

    private List<PgImportRow> rows(UUID batchId) {
        return rowRepository.findAllByBatchIdAndDeletedAtIsNullOrderBySourceRowNumber(batchId);
    }

    private boolean publishable(PgExcelImportParser.ParsedRow row) {
        return publishable(row.validationStatus());
    }

    private boolean publishable(PgImportValidationStatus status) {
        return status == PgImportValidationStatus.READY || status == PgImportValidationStatus.WARNING;
    }

    private String sha256(byte[] content) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(content));
        } catch (Exception error) {
            throw new IllegalStateException("SHA-256 is unavailable", error);
        }
    }

    private String limit(String value, int max) {
        return value.length() <= max ? value : value.substring(0, max);
    }

    private record StoredPhoto(PgImportPhoto photo, String storageKey) { }
}
