package com.sparkage.identity.repository;

import com.sparkage.identity.model.User;
import com.sparkage.identity.service.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("it")
@Transactional(propagation = Propagation.NOT_SUPPORTED)
class UserRepositoryIT {

    @Autowired
    private UserRepository userRepository;

    @BeforeEach
    void clean() {
        userRepository.deleteAll();
    }

    @Test
    void save_and_findByUsernameIgnoreCase_and_findByEmailIgnoreCase() {
        User u = new User();
        u.setUsername("Alice");
        u.setEmail("alice@example.com");
        u.setPasswordHash("hash");

        userRepository.save(u);
        assertThat(u.getId()).isNotNull();
        assertThat(u.getCreatedAt()).isNotNull();

        Optional<User> byUsername = userRepository.findByUsernameIgnoreCase("alice");
        Optional<User> byEmail = userRepository.findByEmailIgnoreCase("ALICE@EXAMPLE.COM");

        assertThat(byUsername).isPresent();
        assertThat(byEmail).isPresent();
        assertThat(byUsername.get().getId()).isEqualTo(u.getId());
        assertThat(byEmail.get().getId()).isEqualTo(u.getId());
    }

    @Test
    void unique_constraints_on_username_and_email_are_enforced() {
        User u1 = new User();
        u1.setUsername("bob");
        u1.setEmail("bob@example.com");
        u1.setPasswordHash("hash");
        userRepository.save(u1);

        User u2 = new User();
        u2.setUsername("bob"); // duplicate username
        u2.setEmail("bob2@example.com");
        u2.setPasswordHash("hash");
        assertThatThrownBy(() -> userRepository.saveAndFlush(u2))
                .isInstanceOf(DataIntegrityViolationException.class);

        User u3 = new User();
        u3.setUsername("bob2");
        u3.setEmail("bob@example.com"); // duplicate email
        u3.setPasswordHash("hash");
        assertThatThrownBy(() -> userRepository.saveAndFlush(u3))
                .isInstanceOf(DataIntegrityViolationException.class);
    }
}
