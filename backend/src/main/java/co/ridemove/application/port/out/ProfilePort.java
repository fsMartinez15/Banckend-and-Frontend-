package co.ridemove.application.port.out;
import co.ridemove.domain.Profile;
import java.util.List;

public interface ProfilePort {
    Profile currentProfile();
    List<Profile> profiles();
    void saveProfile(String name, String phone);
    void setAvailability(boolean available);
    void setActive(String id, boolean active);
}
