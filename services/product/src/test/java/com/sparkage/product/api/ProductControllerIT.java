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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
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

    private Long existingId;

    @BeforeEach
    void setup() {
        productRepository.deleteAll();
        productRepository.save(new Product("Phone X", "Great smartphone", "Electronics", new BigDecimal("799.99")));
        Product saved = productRepository.save(new Product("Laptop Pro", "High-end laptop", "Computers", new BigDecimal("1299.00")));
        existingId = saved.getId();
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

    @Test
    void getProduct_byId_returnsDetails() throws Exception {
        mockMvc.perform(get("/products/" + existingId).accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(existingId))
                .andExpect(jsonPath("$.name").value("Laptop Pro"))
                .andExpect(jsonPath("$.description").value("High-end laptop"))
                .andExpect(jsonPath("$.category").value("Computers"))
                .andExpect(jsonPath("$.price").value(1299.00));
    }

    @Test
    void getProduct_notFound_returns404() throws Exception {
        mockMvc.perform(get("/products/999999").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound());
    }

    @Test
    void createProduct_persistsAndReturns201() throws Exception {
        String json = "{" +
                "\"name\":\"Chair\",\n" +
                "\"description\":\"Office chair\",\n" +
                "\"category\":\"Furniture\",\n" +
                "\"price\":159.50,\n" +
                "\"stock\":12" +
                "}";

        mockMvc.perform(post("/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.name").value("Chair"))
                .andExpect(jsonPath("$.category").value("Furniture"))
                .andExpect(jsonPath("$.price").value(159.50))
                .andExpect(jsonPath("$.stock").value(12));
    }

    @Test
    void createProduct_validationError_returns400() throws Exception {
        String invalid = "{" +
                "\"name\":\"\",\n" +
                "\"price\":-1,\n" +
                "\"stock\":-5" +
                "}";

        mockMvc.perform(post("/products")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(invalid))
                .andExpect(status().isBadRequest());
    }

    @Test
    void sort_byPriceAscAndDesc_returnsExpectedFirstItem() throws Exception {
        // Ascending: the cheapest item (9.99) should be first
        mockMvc.perform(get("/products?sort=price,asc").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].price").value(9.99));

        // Descending: the most expensive item (1299.00) should be first
        mockMvc.perform(get("/products?sort=price,desc").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].price").value(1299.00));
    }

    @Test
    void delete_existing_product_returns204_and_then_get_returns404() throws Exception {
        // existingId is set in setup()
        mockMvc.perform(delete("/products/" + existingId))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/products/" + existingId))
                .andExpect(status().isNotFound());
    }

    @Test
    void delete_non_existing_product_returns404() throws Exception {
        mockMvc.perform(delete("/products/99999999"))
                .andExpect(status().isNotFound());
    }
}
