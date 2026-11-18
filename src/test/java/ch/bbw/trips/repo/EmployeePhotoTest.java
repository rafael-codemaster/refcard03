package ch.bbw.trips.repo;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockMultipartFile;

import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(properties = "app.storage.location=target/test-uploads")
class EmployeePhotoTest {

    private static final byte[] PNG = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D};

    @Autowired
    private EmployeeController controller;

    @Autowired
    private EmployeeRepository employeeRepository;

    @Test
    void uploadedPhotoCanBeDownloaded() throws Exception {
        Employee employee = employeeRepository.save(new Employee(null, "Foto Test", "Tester"));

        controller.uploadPhoto(employee.getId(), new MockMultipartFile("file", "foto.png", "image/png", PNG));
        ResponseEntity<Resource> response = controller.downloadPhoto(employee.getId());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getHeaders().getContentType()).isEqualTo(MediaType.IMAGE_PNG);
        assertThat(response.getBody().getContentAsByteArray()).isEqualTo(PNG);
    }

    @Test
    void newUploadReplacesOldFile() throws Exception {
        Employee employee = employeeRepository.save(new Employee(null, "Foto Ersatz", "Tester"));

        controller.uploadPhoto(employee.getId(), new MockMultipartFile("file", "alt.png", "image/png", PNG));
        String oldFilename = employeeRepository.findById(employee.getId()).orElseThrow().getProfilePictureFilename();
        controller.uploadPhoto(employee.getId(), new MockMultipartFile("file", "neu.png", "image/png", PNG));

        assertThat(Files.exists(Path.of("target/test-uploads", oldFilename))).isFalse();
    }

    @Test
    void downloadWithoutPhotoReturns404() throws Exception {
        Employee employee = employeeRepository.save(new Employee(null, "Ohne Foto", "Tester"));

        ResponseEntity<Resource> response = controller.downloadPhoto(employee.getId());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
