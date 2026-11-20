package br.com.radar.config;

import io.swagger.v3.oas.models.*;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.*;
import org.springframework.context.annotation.*;

@Configuration
public class OpenApiConfig {
  @Bean
  OpenAPI api() {
    return new OpenAPI()
        .info(
            new Info()
                .title("news.dev API")
                .version("v1")
                .description(
                    "API do news.dev (Supabase PostgreSQL). Autentique e use o campo token como Bearer. Rotas admin exigem ADMIN."))
        .components(
            new Components()
                .addSecuritySchemes(
                    "bearerAuth",
                    new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")))
        .addSecurityItem(new SecurityRequirement().addList("bearerAuth"));
  }
}
