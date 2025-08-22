package com.sparkage.product.api.dto;

import java.math.BigDecimal;

public class ProductSummary {
    private Long id;
    private String name;
    private String category;
    private BigDecimal price;

    public ProductSummary() {}

    public ProductSummary(Long id, String name, String category, BigDecimal price) {
        this.id = id;
        this.name = name;
        this.category = category;
        this.price = price;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }
}
