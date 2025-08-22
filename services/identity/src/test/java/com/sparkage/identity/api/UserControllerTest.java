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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.sparkage.identity.model.Role;
import com.sparkage.identity.model.User;
import com.sparkage.identity.service.RoleRepository;
import com.sparkage.identity.service.UserRepository;

@SpringBootTest
@AutoConfigureMockMvc
@org.springframework.test.context.ActiveProfiles("test")
class UserControllerTest {

    @Autowired
    private RoleRepository roleRepository;

    @Autowired
    private UserRepository userRepository;

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

    @Test
    void update_success_returns200_andUpdatedFields() throws Exception {
        String reg = "{\"username\":\"tom\",\"email\":\"tom@example.com\",\"password\":\"Password123\"}";
        String id = objectMapper.readTree(
                mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(reg))
                        .andExpect(status().isCreated())
                        .andReturn()
                        .getResponse()
                        .getContentAsString()
        ).get("id").asText();

        String updateJson = "{\"username\":\"tommy\",\"email\":\"tommy@example.com\"}";
        mockMvc.perform(put("/users/" + id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(updateJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.username").value("tommy"))
                .andExpect(jsonPath("$.email").value("tommy@example.com"));
    }

    @Test
    void update_duplicateUsernameOrEmail_returns400() throws Exception {
        String u1 = "{\"username\":\"dup1\",\"email\":\"dup1@example.com\",\"password\":\"Password123\"}";
        String u2 = "{\"username\":\"dup2\",\"email\":\"dup2@example.com\",\"password\":\"Password123\"}";
        String id1 = objectMapper.readTree(
                mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(u1))
                        .andExpect(status().isCreated())
                        .andReturn().getResponse().getContentAsString()).get("id").asText();
        mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(u2))
                .andExpect(status().isCreated());

        // try to set username to existing one
        mockMvc.perform(put("/users/" + id1)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"dup2\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.duplicate").value("username already taken"));

        // try to set email to existing one
        mockMvc.perform(put("/users/" + id1)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"dup2@example.com\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.duplicate").value("email already registered"));
    }

    @Test
    void update_notFound_returns404() throws Exception {
        String randomId = java.util.UUID.randomUUID().toString();
        mockMvc.perform(put("/users/" + randomId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"nope\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errors.notFound").value("user not found"));
    }

    @Test
    void update_validationErrors_returns400() throws Exception {
        String reg = "{\"username\":\"val\",\"email\":\"val@example.com\",\"password\":\"Password123\"}";
        String id = objectMapper.readTree(
                mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(reg))
                        .andExpect(status().isCreated())
                        .andReturn().getResponse().getContentAsString()).get("id").asText();

        // invalid email and too short username/password
        String bad = "{\"username\":\"ab\",\"email\":\"bad-email\",\"password\":\"short\"}";
        mockMvc.perform(put("/users/" + id)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bad))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.username").exists())
                .andExpect(jsonPath("$.errors.email").exists())
                .andExpect(jsonPath("$.errors.password").exists());
    }

    @Test
    void getUserRoles_empty_returns200AndEmptyList() throws Exception {
        String unique = java.util.UUID.randomUUID().toString().substring(0,8);
        String reg = String.format("{\"username\":\"rolesuser_%s\",\"email\":\"roles_%s@example.com\",\"password\":\"Password123\"}", unique, unique);
        String id = objectMapper.readTree(
                mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(reg))
                        .andExpect(status().isCreated())
                        .andReturn().getResponse().getContentAsString()
        ).get("id").asText();

        mockMvc.perform(get("/users/" + id + "/roles"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void getUserRoles_withAssignedRole_returns200WithRolesAndPermissions() throws Exception {
        String unique = java.util.UUID.randomUUID().toString().substring(0,8);
        String username = "rolesuser2_" + unique;
        String email = "roles2_" + unique + "@example.com";
        String reg = String.format("{\"username\":\"%s\",\"email\":\"%s\",\"password\":\"Password123\"}", username, email);
        String body = mockMvc.perform(post("/users/register").contentType(MediaType.APPLICATION_JSON).content(reg))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String userId = objectMapper.readTree(body).get("id").asText();

        // Create role and assign to user via repositories
        Role role = new Role();
        role.setName("ADMIN_" + unique);
        java.util.Set<String> perms = new java.util.HashSet<>();
        perms.add("USER_READ");
        perms.add("USER_UPDATE");
        role.setPermissions(perms);
        role = roleRepository.save(role);

        java.util.UUID uid = java.util.UUID.fromString(userId);
        User user = userRepository.findById(uid).orElseThrow();
        user.getRoles().add(role);
        userRepository.save(user);

        mockMvc.perform(get("/users/" + userId + "/roles"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(role.getId().toString()))
                .andExpect(jsonPath("$[0].name").value(role.getName()))
                .andExpect(jsonPath("$[0].permissions").isArray())
                .andExpect(jsonPath("$[0].permissions").isNotEmpty());
    }
}