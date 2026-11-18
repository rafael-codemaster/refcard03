package ch.bbw.trips.storage;

public class StorageFileNotFoundException extends RuntimeException {

    public StorageFileNotFoundException(String filename) {
        super("Datei nicht gefunden: " + filename);
    }
}
