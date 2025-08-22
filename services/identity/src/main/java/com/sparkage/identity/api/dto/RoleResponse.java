package com.sparkage.identity.api.dto;

import java.util.List;
import java.util.UUID;

public class RoleResponse {
    private UUID id;
    private String name;
    private List<String> permissions;

    public RoleResponse() {}

    public RoleResponse(UUID id, String name, java.util.Collection<String> permissions) {
        this.id = id;
        this.name = name;
        this.permissions = permissions == null ? java.util.List.of() : java.util.List.copyOf(permissions);
    }

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public List<String> getPermissions() { return permissions; }
    public void setPermissions(List<String> permissions) { this.permissions = permissions; }
}