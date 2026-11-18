package ch.bbw.trips.storage;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.core.io.Resource;
import org.springframework.mock.web.MockMultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class FileStorageServiceTest {

    private static final byte[] PNG = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D};
    private static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 0, 0x10, 'J', 'F', 'I', 'F', 0, 1};

    @TempDir
    Path tempDir;

    private Path storageDir;
    private FileStorageService service;

    @BeforeEach
    void setUp() throws IOException {
        storageDir = tempDir.resolve("uploads");
        service = new FileStorageService(storageDir.toString());
    }

    @Test
    void storesFileUnderUuidNameInStorageDir() throws IOException {
        String filename = service.store(new MockMultipartFile("file", "foto.png", "image/png", PNG));

        assertThat(filename).matches("[0-9a-f-]{36}\\.png");
        assertThat(storageDir.resolve(filename)).exists().hasBinaryContent(PNG);
    }

    @Test
    void extensionComesFromContentTypeNotFromOriginalName() throws IOException {
        String filename = service.store(new MockMultipartFile("file", "shell.jsp", "image/jpeg", JPEG));

        assertThat(filename).endsWith(".jpg");
    }

    @Test
    void rejectsEmptyFile() {
        MockMultipartFile empty = new MockMultipartFile("file", "leer.png", "image/png", new byte[0]);

        assertThatThrownBy(() -> service.store(empty)).isInstanceOf(StorageException.class);
    }

    @Test
    void rejectsUnsupportedContentType() {
        MockMultipartFile text = new MockMultipartFile("file", "notiz.txt", "text/plain", "hallo".getBytes());

        assertThatThrownBy(() -> service.store(text))
                .isInstanceOf(StorageException.class)
                .hasMessageContaining("text/plain");
    }

    @Test
    void rejectsContentThatDoesNotMatchContentType() {
        MockMultipartFile fake = new MockMultipartFile("file", "fake.png", "image/png", "<?php echo 1; ?>".getBytes());

        assertThatThrownBy(() -> service.store(fake)).isInstanceOf(StorageException.class);
    }

    @Test
    void rejectsPathTraversalOnLoadAndDelete() throws IOException {
        Path secret = Files.writeString(tempDir.resolve("secret.txt"), "geheim");

        assertThatThrownBy(() -> service.load("../secret.txt")).isInstanceOf(StorageException.class);
        assertThatThrownBy(() -> service.delete("../secret.txt")).isInstanceOf(StorageException.class);
        assertThat(secret).exists();
    }

    @Test
    void loadReturnsStoredContent() throws IOException {
        String filename = service.store(new MockMultipartFile("file", "foto.png", "image/png", PNG));

        Resource resource = service.load(filename);

        assertThat(resource.getContentAsByteArray()).isEqualTo(PNG);
    }

    @Test
    void loadOfMissingFileThrowsNotFound() {
        assertThatThrownBy(() -> service.load("gibt-es-nicht.png")).isInstanceOf(StorageFileNotFoundException.class);
    }

    @Test
    void deleteRemovesFile() throws IOException {
        String filename = service.store(new MockMultipartFile("file", "foto.png", "image/png", PNG));

        service.delete(filename);

        assertThat(storageDir.resolve(filename)).doesNotExist();
    }
}
