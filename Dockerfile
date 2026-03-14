# ==========================================================
# STAGE 1 : BUILD
# Utilise une image Maven avec JDK pour compiler l'application
# ==========================================================
FROM maven:3.9-eclipse-temurin-17 AS builder
 
# Répertoire de travail dans le conteneur de build
WORKDIR /app
 
# Copier d'abord le pom.xml pour exploiter le cache Docker
# Si pom.xml ne change pas, les dépendances ne sont pas re-téléchargées
COPY pom.xml .
 
# Télécharger toutes les dépendances (sans compiler le code)
RUN mvn dependency:go-offline -B
 
# Copier le code source
COPY src ./src
 
# Compiler et packager l'application (skip tests → exécutés en CI)
RUN mvn clean package -DskipTests -B
 
# ==========================================================
# STAGE 2 : RUNTIME
# Image légère avec seulement le JRE (sans Maven ni JDK complet)
# ==========================================================
FROM eclipse-temurin:17-jre-alpine AS runtime
 
# Métadonnées de l'image
LABEL maintainer="votre-email@exemple.com"
LABEL version="1.0"
LABEL description="Spring Boot Application"

# Créer un utilisateur non-root pour la sécurité
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
 
# Répertoire de travail
WORKDIR /app
 
# Copier UNIQUEMENT le JAR depuis le stage de build
COPY --from=builder /app/target/*.jar app.jar
 
# Changer le propriétaire des fichiers vers l'utilisateur non-root
RUN chown -R appuser:appgroup /app
 
# Utiliser l'utilisateur non-root
USER appuser
 
# Exposer le port Spring Boot (défaut : 8080)
EXPOSE 8080
 
# Variables d'environnement par défaut
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseContainerSupport"
ENV SPRING_PROFILES_ACTIVE=prod
 
# Commande de démarrage avec options JVM
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]

