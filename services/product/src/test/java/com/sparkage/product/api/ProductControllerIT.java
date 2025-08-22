package com.sparkage.product.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sparkage.product.model.Product;
import com.sparkage.product.service.ProductRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ProductControllerIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    void setup() {
        productRepository.deleteAll();
        productRepository.save(new Product("Phone X", "Great smartphone", "Electronics", new BigDecimal("799.99")));
        productRepository.save(new Product("Laptop Pro", "High-end laptop", "Computers", new BigDecimal("1299.00")));
        productRepository.save(new Product("Headphones", "Noise-cancelling headphones", "Electronics", new BigDecimal("199.99")));
        productRepository.save(new Product("Coffee Mug", "Ceramic mug", "Home", new BigDecimal("9.99")));
    }

    @Test
    void get_all_products_default() throws Exception {
        mockMvc.perform(get("/products").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(4));
    }

    @Test
    void pagination_size2_returns2() throws Exception {
        mockMvc.perform(get("/products?page=0&size=2").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));
    }

    @Test
    void search_matchesByNameOrDescription() throws Exception {
        mockMvc.perform(get("/products?search=phone").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].name").exists());
    }

    @Test
    void filter_byCategory_onlyElectronics() throws Exception {
        mockMvc.perform(get("/products?filter=category:Electronics").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].category").value("Electronics"));
    }
}
