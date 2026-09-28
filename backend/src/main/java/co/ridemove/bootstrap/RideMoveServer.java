package co.ridemove.bootstrap;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages="co.ridemove")
public class RideMoveServer {
    public static void main(String[] args) { SpringApplication.run(RideMoveServer.class,args); }
}
