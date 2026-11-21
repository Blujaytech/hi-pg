package com.pgplatform.owner.importer;

import com.pgplatform.auth.PhoneNumbers;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.LocationUrls;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.SupportedCities;
import org.springframework.stereotype.Component;

import javax.xml.stream.XMLInputFactory;
import javax.xml.stream.XMLStreamConstants;
import javax.xml.stream.XMLStreamReader;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

@Component
public class PgExcelImportParser {
    private static final int MAX_ROWS = 5000;
    private static final int MAX_FILE_BYTES = 20 * 1024 * 1024;
    private static final int MAX_UNCOMPRESSED_BYTES = 50 * 1024 * 1024;
    private static final int MAX_ZIP_ENTRIES = 2000;
    private static final int MAX_PHOTOS_PER_ROW = 10;

    public ParsedWorkbook parse(byte[] content, List<Pg> existingPgs) {
        if (content == null || content.length == 0) throw new IllegalArgumentException("Choose a non-empty XLSX file");
        if (content.length > MAX_FILE_BYTES) throw new IllegalArgumentException("Excel file must be 20 MB or smaller");
        if (content.length < 4 || content[0] != 'P' || content[1] != 'K') {
            throw new IllegalArgumentException("Only genuine .xlsx files are supported");
        }
        try {
            Map<String, byte[]> entries = unzip(content);
            if (entries.keySet().stream().anyMatch(name -> name.toLowerCase(Locale.ROOT).contains("vbaproject"))) {
                throw new IllegalArgumentException("Macro-enabled workbooks are not supported");
            }
            SheetReference master = masterSheet(entries);
            List<String> sharedStrings = sharedStrings(entries.get("xl/sharedStrings.xml"));
            List<RawRow> rawRows = sheetRows(entries.get(master.path()), sharedStrings);
            if (rawRows.isEmpty()) throw new IllegalArgumentException("The master sheet contains no rows");
            if (rawRows.size() - 1 > MAX_ROWS) throw new IllegalArgumentException("Excel file exceeds the 5,000 row import limit");
            Map<String, Integer> headers = headers(rawRows.get(0));
            require(headers, "pgname", "streetareaaddress", "city");
            Map<Integer, List<ParsedPhoto>> photos = photos(entries, master, headers, rawRows);

            Set<String> knownKeys = new HashSet<>();
            for (Pg pg : existingPgs) knownKeys.add(dedupeKey(pg.getName(), pg.getAddress(), pg.getCity()));
            Set<String> workbookKeys = new HashSet<>();
            List<ParsedRow> rows = new ArrayList<>();
            for (int index = 1; index < rawRows.size(); index++) {
                RawRow row = rawRows.get(index);
                if (!row.cells().isEmpty()) {
                    rows.add(parseRow(row, headers, knownKeys, workbookKeys,
                            photos.getOrDefault(row.rowNumber(), List.of())));
                }
            }
            if (rows.isEmpty()) throw new IllegalArgumentException("The master sheet contains no PG rows");
            return new ParsedWorkbook(master.name(), rows);
        } catch (IllegalArgumentException error) {
            throw error;
        } catch (Exception error) {
            throw new IllegalArgumentException("The XLSX file could not be read safely");
        }
    }

    private Map<String, byte[]> unzip(byte[] content) throws Exception {
        Map<String, byte[]> entries = new HashMap<>();
        int entryCount = 0;
        int totalBytes = 0;
        try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(content))) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                if (++entryCount > MAX_ZIP_ENTRIES) throw new IllegalArgumentException("XLSX contains too many files");
                if (entry.isDirectory()) continue;
                String name = entry.getName().replace('\\', '/');
                if (name.startsWith("/") || name.contains("../")) throw new IllegalArgumentException("Unsafe XLSX path");
                ByteArrayOutputStream output = new ByteArrayOutputStream();
                byte[] buffer = new byte[8192];
                int read;
                while ((read = zip.read(buffer)) != -1) {
                    totalBytes += read;
                    if (totalBytes > MAX_UNCOMPRESSED_BYTES) throw new IllegalArgumentException("XLSX expands beyond the safety limit");
                    output.write(buffer, 0, read);
                }
                entries.put(name, output.toByteArray());
            }
        }
        if (!entries.containsKey("xl/workbook.xml")) throw new IllegalArgumentException("Invalid XLSX workbook");
        return entries;
    }

    private SheetReference masterSheet(Map<String, byte[]> entries) throws Exception {
        Map<String, String> relationships = new HashMap<>();
        byte[] rels = entries.get("xl/_rels/workbook.xml.rels");
        if (rels == null) throw new IllegalArgumentException("Invalid XLSX relationships");
        XMLStreamReader relReader = reader(rels);
        while (relReader.hasNext()) {
            if (relReader.next() == XMLStreamConstants.START_ELEMENT
                    && "Relationship".equals(relReader.getLocalName())) {
                relationships.put(attribute(relReader, "Id"), attribute(relReader, "Target"));
            }
        }
        relReader.close();

        SheetReference supportedList = null;
        XMLStreamReader workbookReader = reader(entries.get("xl/workbook.xml"));
        while (workbookReader.hasNext()) {
            if (workbookReader.next() == XMLStreamConstants.START_ELEMENT
                    && "sheet".equals(workbookReader.getLocalName())) {
                String name = attribute(workbookReader, "name");
                if (name != null) {
                    String relationshipId = relationshipId(workbookReader);
                    String target = relationships.get(relationshipId);
                    SheetReference sheet = target == null ? null
                            : new SheetReference(name, resolveZipPath("xl/workbook.xml", target));
                    if (name.trim().toUpperCase(Locale.ROOT).startsWith("MASTER")) {
                        workbookReader.close();
                        return requireSheet(entries, sheet);
                    }
                    if ("uniquepglist".equals(normalize(name))) supportedList = sheet;
                }
            }
        }
        workbookReader.close();
        if (supportedList != null) return requireSheet(entries, supportedList);
        throw new IllegalArgumentException("No MASTER or Unique PG List sheet was found in the workbook");
    }

    private SheetReference requireSheet(Map<String, byte[]> entries, SheetReference sheet) {
        if (sheet == null) throw new IllegalArgumentException("Master sheet relationship is missing");
        if (!entries.containsKey(sheet.path())) throw new IllegalArgumentException("Master sheet data is missing");
        return sheet;
    }

    private List<String> sharedStrings(byte[] xml) throws Exception {
        if (xml == null) return List.of();
        List<String> strings = new ArrayList<>();
        XMLStreamReader reader = reader(xml);
        StringBuilder current = null;
        while (reader.hasNext()) {
            int event = reader.next();
            if (event == XMLStreamConstants.START_ELEMENT && "si".equals(reader.getLocalName())) {
                current = new StringBuilder();
            } else if (event == XMLStreamConstants.START_ELEMENT && "t".equals(reader.getLocalName()) && current != null) {
                current.append(reader.getElementText());
            } else if (event == XMLStreamConstants.END_ELEMENT && "si".equals(reader.getLocalName()) && current != null) {
                strings.add(current.toString());
                current = null;
            }
        }
        reader.close();
        return strings;
    }

    private List<RawRow> sheetRows(byte[] xml, List<String> sharedStrings) throws Exception {
        XMLStreamReader reader = reader(xml);
        List<RawRow> rows = new ArrayList<>();
        Map<Integer, String> cells = null;
        int rowNumber = 0;
        String cellType = null;
        int cellColumn = -1;
        String cellValue = null;
        while (reader.hasNext()) {
            int event = reader.next();
            if (event == XMLStreamConstants.START_ELEMENT && "row".equals(reader.getLocalName())) {
                cells = new HashMap<>();
                String rawRowNumber = attribute(reader, "r");
                rowNumber = rawRowNumber == null ? rows.size() + 1 : Integer.parseInt(rawRowNumber);
            } else if (event == XMLStreamConstants.START_ELEMENT && "c".equals(reader.getLocalName())) {
                cellType = attribute(reader, "t");
                cellColumn = column(attribute(reader, "r"));
                cellValue = null;
            } else if (event == XMLStreamConstants.START_ELEMENT
                    && ("v".equals(reader.getLocalName()) || "t".equals(reader.getLocalName()))) {
                cellValue = reader.getElementText();
            } else if (event == XMLStreamConstants.END_ELEMENT && "c".equals(reader.getLocalName()) && cells != null) {
                String value = cellValue;
                if ("s".equals(cellType) && value != null) {
                    int sharedIndex = Integer.parseInt(value);
                    value = sharedIndex >= 0 && sharedIndex < sharedStrings.size() ? sharedStrings.get(sharedIndex) : "";
                }
                if (value != null && !value.trim().isEmpty()) cells.put(cellColumn, value.trim());
            } else if (event == XMLStreamConstants.END_ELEMENT && "row".equals(reader.getLocalName()) && cells != null) {
                rows.add(new RawRow(rowNumber, cells));
                cells = null;
            }
        }
        reader.close();
        return rows;
    }

    private ParsedRow parseRow(RawRow row, Map<String, Integer> headers, Set<String> knownKeys,
                               Set<String> workbookKeys, List<ParsedPhoto> photos) {
        String name = value(row, headers, "pgname", 255);
        String ownerName = value(row, headers, "ownername", 120);
        String rawMobile = value(row, headers, "ownermobile", 40);
        String address = value(row, headers, "streetareaaddress", 500);
        String rawCity = value(row, headers, "city", 120);
        String city = SupportedCities.canonicalOrNull(rawCity);
        String state = value(row, headers, "state", 120);
        String pincode = numericText(value(row, headers, "pincode", 20));
        String locality = value(row, headers, "properlocality", 255);
        String stayType = value(row, headers, "staytype", 120);
        String rawLocationUrl = value(row, headers, 1000, "googlemapssearchurl", "locationurl");
        String imageMarker = value(row, headers, "pgimage", 120);
        List<String> messages = new ArrayList<>();

        if (name == null) messages.add("PG name is required");
        if (address == null) messages.add("Street / area address is required");
        if (city == null) messages.add(rawCity == null ? "City is required" : "City is not supported: " + rawCity);
        String mobile = normalizeMobile(rawMobile, messages);
        Double latitude = number(row, headers, "latitude", -90, 90, messages);
        Double longitude = number(row, headers, "longitude", -180, 180, messages);
        if ((latitude == null) != (longitude == null)) {
            latitude = null;
            longitude = null;
            messages.add("Both latitude and longitude are needed; partial coordinates were ignored");
        } else if (latitude == null) {
            messages.add("Coordinates can be added later");
        }
        String locationUrl = normalizeLocationUrl(rawLocationUrl, messages);
        if (imageMarker != null && !imageMarker.isBlank() && photos.isEmpty()) {
            messages.add("Embedded PG image could not be read");
        }
        GenderPreference gender = gender(stayType);
        if (gender == GenderPreference.UNSPECIFIED) messages.add("Stay type needs review and was marked unspecified");

        boolean invalid = name == null || address == null || city == null;
        String key = invalid ? null : dedupeKey(name, address, city);
        boolean duplicate = key != null && (knownKeys.contains(key) || !workbookKeys.add(key));
        if (duplicate) messages.add("Exact duplicate name, address and city; row will not publish");
        PgImportValidationStatus status = invalid ? PgImportValidationStatus.INVALID
                : duplicate ? PgImportValidationStatus.DUPLICATE
                : messages.isEmpty() ? PgImportValidationStatus.READY : PgImportValidationStatus.WARNING;
        return new ParsedRow(row.rowNumber(), name, ownerName, mobile, address, city, state, pincode,
                latitude, longitude, locationUrl, locality, stayType, gender, status, messages, key, photos);
    }

    private Map<Integer, List<ParsedPhoto>> photos(Map<String, byte[]> entries, SheetReference sheet,
                                                    Map<String, Integer> headers, List<RawRow> rows) throws Exception {
        Integer imageColumn = headers.get("pgimage");
        if (imageColumn == null) return Map.of();
        String drawingRelationshipId = drawingRelationshipId(entries.get(sheet.path()));
        if (drawingRelationshipId == null) return Map.of();
        Map<String, String> sheetRelationships = relationships(entries.get(relationshipsPath(sheet.path())));
        String drawingTarget = sheetRelationships.get(drawingRelationshipId);
        if (drawingTarget == null) return Map.of();
        String drawingPath = resolveZipPath(sheet.path(), drawingTarget);
        Map<String, String> drawingRelationships = relationships(entries.get(relationshipsPath(drawingPath)));
        Map<Integer, List<ParsedPhoto>> result = new HashMap<>();
        XMLStreamReader drawingReader = reader(entries.get(drawingPath));
        int rowNumber = -1;
        int columnNumber = -1;
        String imageRelationshipId = null;
        boolean inFrom = false;
        while (drawingReader.hasNext()) {
            int event = drawingReader.next();
            String localName = event == XMLStreamConstants.START_ELEMENT || event == XMLStreamConstants.END_ELEMENT
                    ? drawingReader.getLocalName() : null;
            if (event == XMLStreamConstants.START_ELEMENT
                    && ("twoCellAnchor".equals(localName) || "oneCellAnchor".equals(localName))) {
                rowNumber = -1;
                columnNumber = -1;
                imageRelationshipId = null;
            } else if (event == XMLStreamConstants.START_ELEMENT && "from".equals(localName)) {
                inFrom = true;
            } else if (event == XMLStreamConstants.END_ELEMENT && "from".equals(localName)) {
                inFrom = false;
            } else if (event == XMLStreamConstants.START_ELEMENT && inFrom && "row".equals(localName)) {
                rowNumber = Integer.parseInt(drawingReader.getElementText()) + 1;
            } else if (event == XMLStreamConstants.START_ELEMENT && inFrom && "col".equals(localName)) {
                columnNumber = Integer.parseInt(drawingReader.getElementText());
            } else if (event == XMLStreamConstants.START_ELEMENT && "blip".equals(localName)) {
                imageRelationshipId = relationshipAttribute(drawingReader, "embed");
            } else if (event == XMLStreamConstants.END_ELEMENT
                    && ("twoCellAnchor".equals(localName) || "oneCellAnchor".equals(localName))) {
                if (columnNumber == imageColumn) {
                    String imageTarget = drawingRelationships.get(imageRelationshipId);
                    String imagePath = imageTarget == null ? null : resolveZipPath(drawingPath, imageTarget);
                    ParsedPhoto photo = parsedPhoto(imagePath, imagePath == null ? null : entries.get(imagePath));
                    List<ParsedPhoto> rowPhotos = result.computeIfAbsent(rowNumber, ignored -> new ArrayList<>());
                    if (photo != null && rowPhotos.size() < MAX_PHOTOS_PER_ROW) rowPhotos.add(photo);
                }
            }
        }
        drawingReader.close();
        result.replaceAll((ignored, value) -> List.copyOf(value));
        return result;
    }

    private ParsedPhoto parsedPhoto(String path, byte[] content) {
        if (path == null || content == null || content.length == 0 || content.length > 5L * 1024 * 1024) return null;
        String contentType;
        String extension;
        if (content.length >= 3 && (content[0] & 0xff) == 0xff
                && (content[1] & 0xff) == 0xd8 && (content[2] & 0xff) == 0xff) {
            contentType = "image/jpeg";
            extension = ".jpg";
        } else if (content.length >= 8 && (content[0] & 0xff) == 0x89
                && content[1] == 0x50 && content[2] == 0x4e && content[3] == 0x47) {
            contentType = "image/png";
            extension = ".png";
        } else {
            return null;
        }
        String fileName = Path.of(path).getFileName().toString();
        if (!fileName.contains(".")) fileName += extension;
        return new ParsedPhoto(fileName, contentType, content);
    }

    private String drawingRelationshipId(byte[] sheetXml) throws Exception {
        XMLStreamReader sheetReader = reader(sheetXml);
        while (sheetReader.hasNext()) {
            if (sheetReader.next() == XMLStreamConstants.START_ELEMENT
                    && "drawing".equals(sheetReader.getLocalName())) {
                String relationshipId = relationshipId(sheetReader);
                sheetReader.close();
                return relationshipId;
            }
        }
        sheetReader.close();
        return null;
    }

    private Map<String, String> relationships(byte[] xml) throws Exception {
        if (xml == null) return Map.of();
        Map<String, String> result = new HashMap<>();
        XMLStreamReader relationshipReader = reader(xml);
        while (relationshipReader.hasNext()) {
            if (relationshipReader.next() == XMLStreamConstants.START_ELEMENT
                    && "Relationship".equals(relationshipReader.getLocalName())) {
                result.put(attribute(relationshipReader, "Id"), attribute(relationshipReader, "Target"));
            }
        }
        relationshipReader.close();
        return result;
    }

    private String relationshipsPath(String path) {
        int separator = path.lastIndexOf('/');
        return path.substring(0, separator + 1) + "_rels/" + path.substring(separator + 1) + ".rels";
    }

    private String resolveZipPath(String sourcePath, String target) {
        if (target.startsWith("/")) return target.substring(1);
        Path parent = Path.of(sourcePath).getParent();
        return parent.resolve(target).normalize().toString().replace('\\', '/');
    }

    private Map<String, Integer> headers(RawRow row) {
        Map<String, Integer> result = new HashMap<>();
        row.cells().forEach((column, value) -> result.put(normalize(value), column));
        return result;
    }

    private void require(Map<String, Integer> headers, String... required) {
        for (String header : required) {
            if (!headers.containsKey(header)) throw new IllegalArgumentException("Required Excel column is missing: " + header);
        }
    }

    private String value(RawRow row, Map<String, Integer> headers, String header, int max) {
        Integer column = headers.get(header);
        if (column == null) return null;
        String value = row.cells().get(column);
        if (value == null || value.isBlank()) return null;
        value = value.trim();
        return value.length() <= max ? value : value.substring(0, max);
    }

    private String value(RawRow row, Map<String, Integer> headers, int max, String... aliases) {
        for (String alias : aliases) {
            String value = value(row, headers, alias, max);
            if (value != null) return value;
        }
        return null;
    }

    private Double number(RawRow row, Map<String, Integer> headers, String header, double min, double max,
                          List<String> messages) {
        String raw = value(row, headers, header, 50);
        if (raw == null) return null;
        try {
            double value = Double.parseDouble(raw.replace(",", ""));
            if (value < min || value > max) throw new NumberFormatException();
            return value;
        } catch (NumberFormatException ignored) {
            messages.add(header + " is invalid and was ignored");
            return null;
        }
    }

    private String normalizeMobile(String rawMobile, List<String> messages) {
        if (rawMobile == null) {
            messages.add("No owner mobile; listing can publish without an invitation");
            return null;
        }
        String[] candidates = rawMobile.split("\\s*[/,;|]\\s*");
        for (String candidate : candidates) {
            try {
                String normalized = PhoneNumbers.normalize(numericText(candidate));
                if (candidates.length > 1) messages.add("Multiple owner numbers found; the first valid mobile will be invited");
                return normalized;
            } catch (IllegalArgumentException ignored) { }
        }
        messages.add("Owner mobile is invalid; invitation will be skipped");
        return null;
    }

    private String normalizeLocationUrl(String raw, List<String> messages) {
        if (raw == null) return null;
        try {
            return LocationUrls.normalizeGoogleMapsUrl(raw);
        } catch (IllegalArgumentException ignored) {
            messages.add("Google Maps URL is invalid and was ignored");
            return null;
        }
    }

    private String numericText(String value) {
        if (value == null) return null;
        return value.endsWith(".0") ? value.substring(0, value.length() - 2) : value;
    }

    private GenderPreference gender(String value) {
        String normalized = value == null ? "" : value.toLowerCase(Locale.ROOT);
        if (normalized.matches(".*(men.*women|women.*men|male.*female|female.*male|co.?liv|co.?ed|mixed).*")) {
            return GenderPreference.CO_ED;
        }
        if (normalized.matches(".*(women|woman|female|girl|ladies|lady).*")) return GenderPreference.FEMALE;
        if (normalized.matches(".*(men|man|male|boy|gent).*")) return GenderPreference.MALE;
        return GenderPreference.UNSPECIFIED;
    }

    private XMLStreamReader reader(byte[] xml) throws Exception {
        if (xml == null) throw new IllegalArgumentException("Required XLSX XML is missing");
        XMLInputFactory factory = XMLInputFactory.newFactory();
        factory.setProperty(XMLInputFactory.SUPPORT_DTD, false);
        factory.setProperty("javax.xml.stream.isSupportingExternalEntities", false);
        return factory.createXMLStreamReader(new ByteArrayInputStream(xml), StandardCharsets.UTF_8.name());
    }

    private String attribute(XMLStreamReader reader, String name) {
        for (int index = 0; index < reader.getAttributeCount(); index++) {
            if (name.equals(reader.getAttributeLocalName(index))) return reader.getAttributeValue(index);
        }
        return null;
    }

    private String relationshipId(XMLStreamReader reader) {
        return relationshipAttribute(reader, "id");
    }

    private String relationshipAttribute(XMLStreamReader reader, String localName) {
        for (int index = 0; index < reader.getAttributeCount(); index++) {
            if (localName.equals(reader.getAttributeLocalName(index))) return reader.getAttributeValue(index);
        }
        return null;
    }

    private int column(String reference) {
        if (reference == null) return -1;
        int result = 0;
        int index = 0;
        while (index < reference.length() && Character.isLetter(reference.charAt(index))) {
            result = result * 26 + Character.toUpperCase(reference.charAt(index)) - 'A' + 1;
            index++;
        }
        return result - 1;
    }

    static String dedupeKey(String name, String address, String city) {
        return normalize(name) + "|" + normalize(address) + "|" + normalize(city);
    }

    private static String normalize(String value) {
        return value == null ? "" : value.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]", "");
    }

    private record SheetReference(String name, String path) { }
    private record RawRow(int rowNumber, Map<Integer, String> cells) { }
    public record ParsedWorkbook(String sheetName, List<ParsedRow> rows) { }
    public record ParsedRow(int sourceRowNumber, String name, String ownerName, String ownerMobile,
                            String address, String city, String state, String pincode, Double latitude,
                            Double longitude, String locationUrl, String properLocality, String originalStayType,
                            GenderPreference genderPreference, PgImportValidationStatus validationStatus,
                            List<String> validationMessages, String dedupeKey, List<ParsedPhoto> photos) {
        public ParsedRow {
            photos = List.copyOf(photos);
        }
    }
    public record ParsedPhoto(String fileName, String contentType, byte[] content) { }
}
