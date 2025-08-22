package com.sparkage.product.api.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

import java.math.BigDecimal;

/**
 * DTO for updating a product. All fields are optional; when present, they must satisfy validation constraints.
 */
public class UpdateProductRequest {
    private String name; // when provided, must be non-blank
    private String description;
    private String category;
    private BigDecimal price; // when provided, must be >= 0.00
    private Integer stock; // when provided, must be >= 0

    public UpdateProductRequest() {}

    // Custom getters with annotations on "virtual" validation methods aren't straightforward;
    // we will validate inside controller by checking constraints when non-null.

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }

    public Integer getStock() { return stock; }
    public void setStock(Integer stock) { this.stock = stock; }
}
