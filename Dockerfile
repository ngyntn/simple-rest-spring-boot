# ============= STAGE 1: Build the application =============
FROM eclipse-temurin:21-jdk-alpine AS builder

# Tạo thư mục làm việc
WORKDIR /app

# Copy file Maven Wrapper và pom.xml trước để tận dụng cache layer
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Download dependencies (layer này sẽ được cache nếu pom.xml không đổi)
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src ./src

# Build ứng dụng, bỏ qua test để nhanh hơn (có thể bỏ -DskipTests nếu muốn chạy test)
RUN ./mvnw clean package -DskipTests -B

# ============= STAGE 2: Create runtime image =============
FROM eclipse-temurin:21-jre-alpine

# Tạo user non-root để chạy app (tăng bảo mật)
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy file JAR từ stage builder
# Spring Boot fat JAR nằm trong target/*.jar
COPY --from=builder /app/target/*.jar app.jar

# Chuyển quyền sở hữu cho user appuser
RUN chown -R appuser:appgroup /app
USER appuser

# Mở port (mặc định Spring Boot là 8080)
EXPOSE 8080

# Health check (tùy chọn nhưng rất khuyến khích)
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Chạy ứng dụng
ENTRYPOINT ["java", "-jar", "app.jar"]
