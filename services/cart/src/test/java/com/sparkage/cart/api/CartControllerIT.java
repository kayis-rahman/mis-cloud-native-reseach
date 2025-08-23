package com.sparkage.cart.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sparkage.cart.service.CartService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class CartControllerIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private CartService cartService;

    @BeforeEach
    void setup() {
        cartService.clearAll();
    }

    @Test
    void addItem_addsNewAndAggregatesOnSecondCall() throws Exception {
        String body = "{\n" +
                "  \"productId\": 55,\n" +
                "  \"quantity\": 2\n" +
                "}";

        mockMvc.perform(post("/carts/7/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(7))
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].productId").value(55))
                .andExpect(jsonPath("$.items[0].quantity").value(2));

        String body2 = "{\n" +
                "  \"productId\": 55,\n" +
                "  \"quantity\": 3\n" +
                "}";

        mockMvc.perform(post("/carts/7/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body2))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(7))
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].productId").value(55))
                .andExpect(jsonPath("$.items[0].quantity").value(5));
    }

    @Test
    void addItem_invalid_returns400() throws Exception {
        String invalid = "{\n" +
                "  \"quantity\": 0\n" +
                "}";

        mockMvc.perform(post("/carts/7/items")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(invalid))
                .andExpect(status().isBadRequest());
    }

    @Test
    void getCart_afterAddingItems_returnsAggregatedCart() throws Exception {
        String body = "{\n" +
                "  \"productId\": 10,\n" +
                "  \"quantity\": 1\n" +
                "}";
        mockMvc.perform(post("/carts/3/items").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk());
        String body2 = "{\n" +
                "  \"productId\": 10,\n" +
                "  \"quantity\": 4\n" +
                "}";
        mockMvc.perform(post("/carts/3/items").contentType(MediaType.APPLICATION_JSON).content(body2))
                .andExpect(status().isOk());

        mockMvc.perform(get("/carts/3").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(3))
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].productId").value(10))
                .andExpect(jsonPath("$.items[0].quantity").value(5));
    }

    @Test
    void getCart_noItems_returnsEmptyCart() throws Exception {
        mockMvc.perform(get("/carts/999").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(999))
                .andExpect(jsonPath("$.items.length()").value(0));
    }

    @Test
    void put_updatesQuantity_and_delete_removesItem() throws Exception {
        // Add item
        String add = "{\n  \"productId\": 200,\n  \"quantity\": 2\n}";
        mockMvc.perform(post("/carts/10/items").contentType(MediaType.APPLICATION_JSON).content(add))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].quantity").value(2));
        // Update to exact quantity 7
        String putBody = "{\n  \"quantity\": 7\n}";
        mockMvc.perform(put("/carts/10/items/200").contentType(MediaType.APPLICATION_JSON).content(putBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].quantity").value(7));
        // Delete
        mockMvc.perform(delete("/carts/10/items/200"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(0));
    }

    @Test
    void put_delete_notFound_return404() throws Exception {
        // No item exists yet
        mockMvc.perform(put("/carts/11/items/999").contentType(MediaType.APPLICATION_JSON).content("{\n  \"quantity\": 3\n}"))
                .andExpect(status().isNotFound());
        mockMvc.perform(delete("/carts/11/items/999"))
                .andExpect(status().isNotFound());
    }

    @Test
    void clear_cart_endpoint_clearsCart_and_nonExistingReturnsEmpty() throws Exception {
        // Add items then clear
        mockMvc.perform(post("/carts/20/items").contentType(MediaType.APPLICATION_JSON).content("{\n  \"productId\": 1,\n  \"quantity\": 5\n}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1));

        mockMvc.perform(post("/carts/20/clear"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(0));

        // Clearing a cart that doesn't exist should still return empty
        mockMvc.perform(post("/carts/21/clear"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(21))
                .andExpect(jsonPath("$.items.length()").value(0));

        // And GET should confirm it stays empty
        mockMvc.perform(get("/carts/20"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(20))
                .andExpect(jsonPath("$.items.length()").value(0));
    }
}
