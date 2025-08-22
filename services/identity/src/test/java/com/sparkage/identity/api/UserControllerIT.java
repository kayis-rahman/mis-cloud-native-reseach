package com.sparkage.identity.api;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("it")
class UserControllerIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void register_then_update_then_getById_returnsUpdatedUser_fromRealDB() throws Exception {
        String unique = UUID.randomUUID().toString().substring(0, 8);
        String username = "ituser_" + unique;
        String email = "it_" + unique + "@example.com";
        String regJson = String.format("{\"username\":\"%s\",\"email\":\"%s\",\"password\":\"Password123\"}", username, email);

        String response = mockMvc.perform(post("/users/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(regJson))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode node = objectMapper.readTree(response);
        String id = node.get("id").asText();

        // Update username and email
        String newUsername = username + "_upd";
        String newEmail = "upd_" + unique + "@example.com";
        String updateJson = String.format("{\"username\":\"%s\",\"email\":\"%s\"}", newUsername, newEmail);
        mockMvc.perform(put("/users/" + id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(updateJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.username").value(newUsername))
                .andExpect(jsonPath("$.email").value(newEmail));

        // Verify via GET
        mockMvc.perform(get("/users/" + id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.username").value(newUsername))
                .andExpect(jsonPath("$.email").value(newEmail))
                .andExpect(jsonPath("$.createdAt").exists());
    }
}
