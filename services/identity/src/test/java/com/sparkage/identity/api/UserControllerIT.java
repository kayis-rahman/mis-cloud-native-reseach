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

import com.sparkage.identity.model.Role;
import com.sparkage.identity.model.User;
import com.sparkage.identity.service.RoleRepository;
import com.sparkage.identity.service.UserRepository;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("it")
class UserControllerIT {

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private UserRepository userRepository;

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

    @Test
    void getUserRoles_returnsRolesAndPermissions_fromRealDB() throws Exception {
        String unique = java.util.UUID.randomUUID().toString().substring(0,8);
        String username = "it_role_user_" + unique;
        String email = "it_role_" + unique + "@example.com";
        String regJson = String.format("{\"username\":\"%s\",\"email\":\"%s\",\"password\":\"Password123\"}", username, email);
        String response = mockMvc.perform(post("/users/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(regJson))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String userId = objectMapper.readTree(response).get("id").asText();

        Role r = new Role();
        r.setName("ADMIN_IT_" + unique);
        java.util.Set<String> perms = new java.util.HashSet<>();
        perms.add("USER_READ");
        perms.add("USER_UPDATE");
        r.setPermissions(perms);
        r = roleRepository.save(r);

        java.util.UUID uid = java.util.UUID.fromString(userId);
        User u = userRepository.findById(uid).orElseThrow();
        u.getRoles().add(r);
        userRepository.save(u);

        mockMvc.perform(get("/users/" + userId + "/roles"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(r.getId().toString()))
                .andExpect(jsonPath("$[0].name").value(r.getName()))
                .andExpect(jsonPath("$[0].permissions").isArray())
                .andExpect(jsonPath("$[0].permissions").isNotEmpty());
    }
}
