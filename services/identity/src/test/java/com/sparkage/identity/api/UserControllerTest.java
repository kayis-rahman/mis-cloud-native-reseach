package com.sparkage.identity.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@org.springframework.test.context.ActiveProfiles("test")
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void register_success_returns201AndUser() throws Exception {
        String json = "{\"username\":\"john_doe\",\"email\":\"john@example.com\",\"password\":\"Password123\"}";

        mockMvc.perform(post("/users/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.username").value("john_doe"))
                .andExpect(jsonPath("$.email").value("john@example.com"))
                .andExpect(jsonPath("$.createdAt").exists());
    }

    @Test
    void register_validationErrors_returns400() throws Exception {
        String invalidJson = "{\"username\":\"\",\"email\":\"not-an-email\",\"password\":\"123\"}";

        mockMvc.perform(post("/users/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(invalidJson))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.username").exists())
                .andExpect(jsonPath("$.errors.email").exists())
                .andExpect(jsonPath("$.errors.password").exists());
    }

    @Test
    void register_duplicateUsernameOrEmail_returns400() throws Exception {
        String json1 = "{\"username\":\"jane\",\"email\":\"jane@example.com\",\"password\":\"Password123\"}";
        String json2 = "{\"username\":\"jane\",\"email\":\"jane2@example.com\",\"password\":\"Password123\"}";

        mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(json1))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(json2))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.duplicate").value("username already taken"));

        String json3 = "{\"username\":\"jane2\",\"email\":\"jane@example.com\",\"password\":\"Password123\"}";
        mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(json3))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.duplicate").value("email already registered"));
    }
}