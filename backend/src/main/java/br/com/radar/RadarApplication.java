package br.com.radar;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@org.springframework.scheduling.annotation.EnableScheduling
@SpringBootApplication
public class RadarApplication {
  public static void main(String[] args) {
    SpringApplication.run(RadarApplication.class, args);
  }
}
