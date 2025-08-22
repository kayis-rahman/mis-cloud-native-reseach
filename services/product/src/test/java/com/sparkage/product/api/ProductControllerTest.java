package com.sparkage.product.api;

import com.sparkage.product.model.Product;
import com.sparkage.product.service.ProductRepository;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.domain.*;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Collections;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(ProductController.class)
class ProductControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private ProductRepository productRepository;

    @Test
    void listProducts_returnsProductSummaries() throws Exception {
        Product p = new Product("Phone X", "Great phone", "Electronics", new BigDecimal("799.99"));
        p.setId(1L);
        Page<Product> page = new PageImpl<>(Collections.singletonList(p), PageRequest.of(0,20), 1);
        Mockito.when(productRepository.findAll(any(org.springframework.data.jpa.domain.Specification.class), any(Pageable.class)))
                .thenReturn(page);

        mockMvc.perform(get("/products").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$[0].id").value(1))
                .andExpect(jsonPath("$[0].name").value("Phone X"))
                .andExpect(jsonPath("$[0].category").value("Electronics"))
                .andExpect(jsonPath("$[0].price").value(799.99));
    }

    @Test
    void getProduct_success_returnsDetails() throws Exception {
        Product p = new Product("Laptop Pro", "High-end laptop", "Computers", new BigDecimal("1299.00"));
        p.setId(42L);
        p.setCreatedAt(Instant.parse("2024-01-01T00:00:00Z"));
        Mockito.when(productRepository.findById(eq(42L))).thenReturn(Optional.of(p));

        mockMvc.perform(get("/products/42").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(42))
                .andExpect(jsonPath("$.name").value("Laptop Pro"))
                .andExpect(jsonPath("$.description").value("High-end laptop"))
                .andExpect(jsonPath("$.category").value("Computers"))
                .andExpect(jsonPath("$.price").value(1299.00))
                .andExpect(jsonPath("$.createdAt").value("2024-01-01T00:00:00Z"));
    }

    @Test
    void getProduct_notFound_returns404() throws Exception {
        Mockito.when(productRepository.findById(eq(999L))).thenReturn(Optional.empty());

        mockMvc.perform(get("/products/999").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }

    @Test
    void createProduct_success_returns201AndBody() throws Exception {
        Product toReturn = new Product("New Gadget", "Cool gadget", "Gadgets", new BigDecimal("49.99"));
        toReturn.setId(100L);
        toReturn.setStock(5);
        toReturn.setCreatedAt(Instant.parse("2025-01-01T00:00:00Z"));
        Mockito.when(productRepository.save(any(Product.class))).thenReturn(toReturn);

        String json = "{" +
                "\"name\":\"New Gadget\",\n" +
                "\"description\":\"Cool gadget\",\n" +
                "\"category\":\"Gadgets\",\n" +
                "\"price\":49.99,\n" +
                "\"stock\":5" +
                "}";

        mockMvc.perform(post("/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/products/100"))
                .andExpect(jsonPath("$.id").value(100))
                .andExpect(jsonPath("$.name").value("New Gadget"))
                .andExpect(jsonPath("$.category").value("Gadgets"))
                .andExpect(jsonPath("$.price").value(49.99))
                .andExpect(jsonPath("$.stock").value(5))
                .andExpect(jsonPath("$.createdAt").value("2025-01-01T00:00:00Z"));
    }

    @Test
    void createProduct_validationErrors_returns400() throws Exception {
        String invalid = "{" +
                "\"name\":\"\",\n" +
                "\"price\":-10,\n" +
                "\"stock\":-1" +
                "}";

        mockMvc.perform(post("/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(invalid))
                .andExpect(status().isBadRequest());
    }
}
