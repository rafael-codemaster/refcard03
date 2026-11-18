package ch.bbw.trips.repo;

import ch.bbw.trips.ex.TriptNotFoundException;
import ch.bbw.trips.storage.FileStorageService;
import lombok.AllArgsConstructor;
import lombok.Data;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.MediaTypeFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.MalformedURLException;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/v1")
public class EmployeeController {
    private static final Logger log = LoggerFactory.getLogger(EmployeeController.class);

    @Autowired
    private EmployeeRepository employeeRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private FileStorageService fileStorageService;

    @PostMapping("/signIn")
    @ResponseStatus(HttpStatus.OK)
    ResponseEntity<?> signIn(@RequestBody Employee authenticationUser) {
        Optional<Employee> userOptional = employeeRepository.findUserByUsername(authenticationUser.getUsername());

        if (userOptional.isPresent()) {
            Employee user = userOptional.get();
            if (passwordEncoder.matches(authenticationUser.getPassword(), user.getPassword())) {
                String uuid = UUID.randomUUID().toString();
                user.setToken(uuid);
                employeeRepository.save(user);
                log.info("User logged in: " + user);

                TokenResponse response = new TokenResponse(uuid);
                return ResponseEntity
                        .status(HttpStatus.OK)
                        .header("Authorization", "Bearer " + uuid)
                        .body(response);
            }
        }
        return ResponseEntity.notFound().build();
    }

    // POJO to represent the response body
    @Data
    @AllArgsConstructor
    private static class TokenResponse {
        private String token;
    }

    @GetMapping("/employees")
    List<Employee> allEmployees() {
        return (List<Employee>) employeeRepository.findAll();
    }

    @PostMapping("/employees")
    Employee createEmployee(@RequestBody Employee newItem) {
        if (newItem.getPassword() != null) {
            newItem.setPassword(passwordEncoder.encode(newItem.getPassword()));
        }
        return employeeRepository.save(newItem);
    }

    @GetMapping("/employees/{id}")
    Employee one(@PathVariable Long id) {
        return employeeRepository.findById(id).orElseThrow(() -> new TriptNotFoundException(id));
    }

    @PutMapping("/employees/{id}")
    Employee updateEmployee(@RequestBody Employee newItem, @PathVariable Long id) {
        return employeeRepository.findById(id).map(item -> {
            item.setName(newItem.getName());
            item.setJobTitle(newItem.getJobTitle());
            return employeeRepository.save(item);
        }).orElseGet(() -> {
            newItem.setId(id);
            return employeeRepository.save(newItem);
        });
    }

    @DeleteMapping("/employees/{id}")
    void deleteEmployee(@PathVariable Long id) {
        employeeRepository.deleteById(id);
    }

    @DeleteMapping("/employees")
    void deleteAllEmployees() {
        employeeRepository.deleteAll();
    }

    // EX-04: Mitarbeiterfoto hoch-/runterladen

    @PostMapping(value = "/employees/{id}/photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    ResponseEntity<Void> uploadPhoto(@PathVariable Long id, @RequestParam("file") MultipartFile file) throws IOException {
        Employee employee = employeeRepository.findById(id).orElseThrow(() -> new TriptNotFoundException(id));
        String previous = employee.getProfilePictureFilename();
        employee.setProfilePictureFilename(fileStorageService.store(file));
        employeeRepository.save(employee);
        fileStorageService.delete(previous);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/employees/{id}/photo")
    ResponseEntity<Resource> downloadPhoto(@PathVariable Long id) throws MalformedURLException {
        Employee employee = employeeRepository.findById(id).orElseThrow(() -> new TriptNotFoundException(id));
        String filename = employee.getProfilePictureFilename();
        if (filename == null) {
            return ResponseEntity.notFound().build();
        }
        Resource resource = fileStorageService.load(filename);
        MediaType contentType = MediaTypeFactory.getMediaType(filename).orElse(MediaType.APPLICATION_OCTET_STREAM);
        return ResponseEntity.ok()
                .contentType(contentType)
                .body(resource);
    }

    @DeleteMapping("/employees/{id}/photo")
    ResponseEntity<Void> deletePhoto(@PathVariable Long id) throws IOException {
        Employee employee = employeeRepository.findById(id).orElseThrow(() -> new TriptNotFoundException(id));
        fileStorageService.delete(employee.getProfilePictureFilename());
        employee.setProfilePictureFilename(null);
        employeeRepository.save(employee);
        return ResponseEntity.noContent().build();
    }

}
