package ch.bbw.trips.storage;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Map;
import java.util.UUID;

/**
 * Legt Mitarbeiterfotos im Dateisystem unter {@code app.storage.location} ab.
 * Vorstufe zu S3 (RefCard 05): store() liefert eine Referenz, load() eine Resource.
 */
@Service
public class FileStorageService {

    // Endung wird aus dem geprüften Content-Type abgeleitet, nie aus dem Original-Dateinamen
    private static final Map<String, String> ALLOWED_TYPES = Map.of(
            "image/png", "png",
            "image/jpeg", "jpg",
            "image/webp", "webp");

    private final Path root;

    public FileStorageService(@Value("${app.storage.location}") String location) throws IOException {
        this.root = Paths.get(location).toAbsolutePath().normalize();
        Files.createDirectories(root);
    }

    public String store(MultipartFile file) throws IOException {
        if (file == null || file.isEmpty()) {
            throw new StorageException("Datei ist leer");
        }
        String extension = ALLOWED_TYPES.get(file.getContentType());
        if (extension == null) {
            throw new StorageException("Nicht unterstützter Dateityp: " + file.getContentType());
        }
        try (InputStream in = file.getInputStream()) {
            if (!hasImageSignature(in.readNBytes(12), extension)) {
                throw new StorageException("Dateiinhalt passt nicht zum Typ " + file.getContentType());
            }
        }

        String filename = UUID.randomUUID() + "." + extension;
        Path target = resolveInsideRoot(filename);
        try (InputStream in = file.getInputStream()) {
            Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
        }
        return filename;
    }

    public Resource load(String filename) throws MalformedURLException {
        Path file = resolveInsideRoot(filename);
        Resource resource = new UrlResource(file.toUri());
        if (!resource.exists() || !resource.isReadable()) {
            throw new StorageFileNotFoundException(filename);
        }
        return resource;
    }

    public void delete(String filename) throws IOException {
        if (filename == null) {
            return;
        }
        Files.deleteIfExists(resolveInsideRoot(filename));
    }

    private Path resolveInsideRoot(String filename) {
        Path target = root.resolve(filename).normalize();
        if (!root.equals(target.getParent())) {
            throw new StorageException("Ungültiger Dateipfad");
        }
        return target;
    }

    private static boolean hasImageSignature(byte[] header, String extension) {
        return switch (extension) {
            case "png" -> startsWith(header, 0x89, 'P', 'N', 'G');
            case "jpg" -> startsWith(header, 0xFF, 0xD8, 0xFF);
            case "webp" -> startsWith(header, 'R', 'I', 'F', 'F')
                    && header.length >= 12
                    && header[8] == 'W' && header[9] == 'E' && header[10] == 'B' && header[11] == 'P';
            default -> false;
        };
    }

    private static boolean startsWith(byte[] header, int... signature) {
        if (header.length < signature.length) {
            return false;
        }
        for (int i = 0; i < signature.length; i++) {
            if ((header[i] & 0xFF) != signature[i]) {
                return false;
            }
        }
        return true;
    }
}
