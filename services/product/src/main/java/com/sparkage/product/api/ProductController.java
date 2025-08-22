package com.sparkage.product.api;

import com.sparkage.product.api.dto.ProductSummary;
import com.sparkage.product.model.Product;
import com.sparkage.product.service.ProductRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/products")
public class ProductController {

    private final ProductRepository repository;

    public ProductController(ProductRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<ProductSummary> listProducts(
            @RequestParam(value = "filter", required = false) String filter,
            @RequestParam(value = "search", required = false) String search,
            @RequestParam(value = "page", defaultValue = "0") int page,
            @RequestParam(value = "size", defaultValue = "20") int size,
            @RequestParam(value = "sort", required = false) String sort
    ) {
        Pageable pageable = toPageable(page, size, sort);
        Specification<Product> spec = buildSpecification(filter, search);
        Page<Product> result = repository.findAll(spec, pageable);
        return result.getContent().stream()
                .map(p -> new ProductSummary(p.getId(), p.getName(), p.getCategory(), p.getPrice()))
                .collect(Collectors.toList());
    }

    private Pageable toPageable(int page, int size, String sort) {
        if (size <= 0) size = 20;
        if (page < 0) page = 0;
        if (!StringUtils.hasText(sort)) {
            return PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        }
        // support sort patterns like "price,asc" or "name,desc"
        String[] parts = sort.split(",");
        String property = parts[0];
        Sort.Direction dir = parts.length > 1 && parts[1].equalsIgnoreCase("asc") ? Sort.Direction.ASC : Sort.Direction.DESC;
        return PageRequest.of(page, size, Sort.by(dir, property));
    }

    private Specification<Product> buildSpecification(String filter, String search) {
        Specification<Product> spec = Specification.where(null);
        if (StringUtils.hasText(search)) {
            String q = search.toLowerCase(Locale.ROOT);
            spec = spec.and((root, query, cb) -> cb.or(
                    cb.like(cb.lower(root.get("name")), "%" + q + "%"),
                    cb.like(cb.lower(root.get("description")), "%" + q + "%")
            ));
        }
        if (StringUtils.hasText(filter)) {
            // very simple key:value pairs separated by commas, only "category" is supported
            String[] parts = filter.split(",");
            for (String part : parts) {
                String[] kv = part.split(":", 2);
                if (kv.length == 2) {
                    String key = kv[0].trim().toLowerCase(Locale.ROOT);
                    String value = kv[1].trim();
                    if ("category".equals(key)) {
                        spec = spec.and((root, query, cb) -> cb.equal(root.get("category"), value));
                    }
                }
            }
        }
        return spec;
    }
}
