package com.sparkage.apigateway.config;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.LoggerContext;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.Appender;
import ch.qos.logback.core.ConsoleAppender;
import ch.qos.logback.core.rolling.RollingFileAppender;
import net.logstash.logback.appender.LogstashTcpSocketAppender;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.util.Iterator;

import static org.assertj.core.api.Assertions.assertThat;

public class LoggingConfigurationTest {

    @SpringBootTest
    @ActiveProfiles("development")
    static class DevelopmentProfileTest {

        @Test
        void shouldConfigureDevelopmentLogging() {
            LoggerContext context = (LoggerContext) LoggerFactory.getILoggerFactory();
            Logger rootLogger = context.getLogger(Logger.ROOT_LOGGER_NAME);
            Logger sparkageLogger = context.getLogger("com.sparkage");
            Logger gatewayLogger = context.getLogger("org.springframework.cloud.gateway");

            // Check log levels
            assertThat(rootLogger.getLevel()).hasToString("INFO");
            assertThat(sparkageLogger.getLevel()).hasToString("DEBUG");
            assertThat(gatewayLogger.getLevel()).hasToString("DEBUG");

            // Check appenders - development should only have console
            Iterator<Appender<ILoggingEvent>> appenders = rootLogger.iteratorForAppenders();
            boolean hasConsoleAppender = false;
            while (appenders.hasNext()) {
                Appender<ILoggingEvent> appender = appenders.next();
                if (appender instanceof ConsoleAppender) {
                    hasConsoleAppender = true;
                }
            }
            assertThat(hasConsoleAppender).isTrue();
        }
    }

    @SpringBootTest
    @ActiveProfiles("staging")
    static class StagingProfileTest {

        @Test
        void shouldConfigureStagingLogging() {
            LoggerContext context = (LoggerContext) LoggerFactory.getILoggerFactory();
            Logger rootLogger = context.getLogger(Logger.ROOT_LOGGER_NAME);

            // Check log levels
            assertThat(rootLogger.getLevel()).hasToString("INFO");

            // Check appenders - should have both console and file
            Iterator<Appender<ILoggingEvent>> appenders = rootLogger.iteratorForAppenders();
            boolean hasConsoleAppender = false;
            boolean hasFileAppender = false;

            while (appenders.hasNext()) {
                Appender<ILoggingEvent> appender = appenders.next();
                if (appender instanceof ConsoleAppender) {
                    hasConsoleAppender = true;
                } else if (appender instanceof RollingFileAppender) {
                    hasFileAppender = true;
                }
            }

            assertThat(hasConsoleAppender).isTrue();
            assertThat(hasFileAppender).isTrue();
        }
    }

    @SpringBootTest
    @ActiveProfiles("production")
    static class ProductionProfileTest {

        @Test
        void shouldConfigureProductionLogging() {
            LoggerContext context = (LoggerContext) LoggerFactory.getILoggerFactory();
            Logger rootLogger = context.getLogger(Logger.ROOT_LOGGER_NAME);

            // Check log levels - production should be more restrictive
            assertThat(rootLogger.getLevel()).hasToString("WARN");

            // Check appenders - should have console, file, and logstash
            Iterator<Appender<ILoggingEvent>> appenders = rootLogger.iteratorForAppenders();
            boolean hasConsoleAppender = false;
            boolean hasFileAppender = false;
            boolean hasLogstashAppender = false;

            while (appenders.hasNext()) {
                Appender<ILoggingEvent> appender = appenders.next();
                if (appender instanceof ConsoleAppender) {
                    hasConsoleAppender = true;
                } else if (appender instanceof RollingFileAppender) {
                    hasFileAppender = true;
                } else if (appender instanceof LogstashTcpSocketAppender) {
                    hasLogstashAppender = true;
                }
            }

            assertThat(hasConsoleAppender).isTrue();
            assertThat(hasFileAppender).isTrue();
            assertThat(hasLogstashAppender).isTrue();
        }
    }

    @SpringBootTest
    @ActiveProfiles("test")
    static class TestProfileTest {

        @Test
        void shouldConfigureTestLogging() {
            LoggerContext context = (LoggerContext) LoggerFactory.getILoggerFactory();
            Logger rootLogger = context.getLogger(Logger.ROOT_LOGGER_NAME);
            Logger sparkageLogger = context.getLogger("com.sparkage");

            // Check log levels
            assertThat(rootLogger.getLevel()).hasToString("WARN");
            assertThat(sparkageLogger.getLevel()).hasToString("DEBUG");

            // Check appenders - should only have console for tests
            Iterator<Appender<ILoggingEvent>> appenders = rootLogger.iteratorForAppenders();
            boolean hasConsoleAppender = false;

            while (appenders.hasNext()) {
                Appender<ILoggingEvent> appender = appenders.next();
                if (appender instanceof ConsoleAppender) {
                    hasConsoleAppender = true;
                }
            }

            assertThat(hasConsoleAppender).isTrue();
        }
    }
}
