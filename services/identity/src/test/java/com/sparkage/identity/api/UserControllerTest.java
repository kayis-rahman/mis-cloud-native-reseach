package com.sparkage.identity.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

    @Test
    void login_success_withUsernameOrEmail_returnsTokenAndUser() throws Exception {
        String reg = "{\"username\":\"mark\",\"email\":\"mark@example.com\",\"password\":\"Password123\"}";
        mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(reg))
                .andExpect(status().isCreated());

        String loginByUsername = "{\"usernameOrEmail\":\"mark\",\"password\":\"Password123\"}";
        mockMvc.perform(post("/users/login").contentType(MediaType.APPLICATION_JSON).content(loginByUsername))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").exists())
                .andExpect(jsonPath("$.user.username").value("mark"))
                .andExpect(jsonPath("$.user.email").value("mark@example.com"));

        String loginByEmail = "{\"usernameOrEmail\":\"mark@example.com\",\"password\":\"Password123\"}";
        mockMvc.perform(post("/users/login").contentType(MediaType.APPLICATION_JSON).content(loginByEmail))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").exists())
                .andExpect(jsonPath("$.user.username").value("mark"))
                .andExpect(jsonPath("$.user.email").value("mark@example.com"));
    }

    @Test
    void login_invalidCredentials_returns401() throws Exception {
        String reg = "{\"username\":\"kate\",\"email\":\"kate@example.com\",\"password\":\"Password123\"}";
        mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(reg))
                .andExpect(status().isCreated());

        String badLogin = "{\"usernameOrEmail\":\"kate\",\"password\":\"wrong\"}";
        mockMvc.perform(post("/users/login").contentType(MediaType.APPLICATION_JSON).content(badLogin))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errors.auth").value("invalid credentials"));
    }

    @Test
    void getUser_success_returns200() throws Exception {
        String reg = "{\"username\":\"paul\",\"email\":\"paul@example.com\",\"password\":\"Password123\"}";
        String id = objectMapper.readTree(
                mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(reg))
                        .andExpect(status().isCreated())
                        .andReturn()
                        .getResponse()
                        .getContentAsString()
        ).get("id").asText();

        mockMvc.perform(get("/users/" + id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.username").value("paul"))
                .andExpect(jsonPath("$.email").value("paul@example.com"))
                .andExpect(jsonPath("$.createdAt").exists());
    }

    @Test
    void getUser_notFound_returns404() throws Exception {
        String randomId = java.util.UUID.randomUUID().toString();
        mockMvc.perform(get("/users/" + randomId))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errors.notFound").value("user not found"));
    }
}