# Spring Maven — Pipeline CI/CD complet

Application Spring Boot avec pipeline CI/CD automatisé via GitHub Actions, Docker Hub et déploiement SSH.

---

## Table des matières

1. [Architecture du projet](#1-architecture-du-projet)
2. [Prérequis](#2-prérequis)
3. [Structure des fichiers](#3-structure-des-fichiers)
4. [Pipeline CI/CD — Vue d'ensemble](#4-pipeline-cicd--vue-densemble)
5. [Job 1 — Tests Maven](#5-job-1--tests-maven)
6. [Job 2 — Build & Push Docker](#6-job-2--build--push-docker)
7. [Job 3 — Déploiement Production](#7-job-3--déploiement-production)
8. [Configuration des secrets GitHub](#8-configuration-des-secrets-github)
9. [Déploiement sur PC personnel (Windows 11)](#9-déploiement-sur-pc-personnel-windows-11)
10. [Lancer l'application en local](#10-lancer-lapplication-en-local)

---

## 1. Architecture du projet

```
GitHub (push sur main)
        │
        ▼
GitHub Actions Runner (cloud Ubuntu)
        │
        ├── Job 1 : Tests Maven (JUnit)
        │
        ├── Job 2 : Build image Docker → push sur Docker Hub
        │
        └── Job 3 : SSH vers le serveur → docker pull + docker run
                          │
                          ▼
               Serveur cible (ton PC / VPS)
               └── spring-maven-app:8080
```

---

## 2. Prérequis

| Outil | Version | Usage |
|---|---|---|
| Java (JDK) | 17 | Compiler l'application |
| Maven | 3.9+ | Build & tests |
| Docker Desktop | dernière | Build et run des conteneurs |
| Git | dernière | Versioning |
| Compte GitHub | — | Hébergement code + CI |
| Compte Docker Hub | — | Registre d'images |
| ngrok (optionnel) | dernière | Exposer ton PC au CI |

---

## 3. Structure des fichiers

```
spring-maven/
├── src/                          # Code source Java
│   └── main/java/...
├── .github/
│   └── workflows/
│       └── deploy.yml            # Pipeline CI/CD complet
├── Dockerfile                    # Image Docker multi-stage
├── pom.xml                       # Configuration Maven + dépendances
└── README.md                     # Ce fichier
```

---

## 4. Pipeline CI/CD — Vue d'ensemble

Le fichier [.github/workflows/deploy.yml](.github/workflows/deploy.yml) définit 3 jobs qui s'enchaînent automatiquement à chaque `git push` sur `main`.

**Déclencheurs :**
- `push` sur la branche `main`
- `pull_request` vers `main`
- Déclenchement manuel (bouton "Run workflow" sur GitHub)

**Flux :**
```
Tests OK  →  Build Docker OK  →  Déploiement SSH
```
Si un job échoue, les suivants ne s'exécutent pas.

---

## 5. Job 1 — Tests Maven

**Fichier :** [.github/workflows/deploy.yml](.github/workflows/deploy.yml) — section `test`

Ce job vérifie que le code compile et que tous les tests passent.

**Étapes :**

| Étape | Action |
|---|---|
| Checkout | Récupère le code depuis GitHub |
| Setup JDK 17 | Installe Java avec cache Maven automatique |
| Exécution des tests | `mvn test` — lance tous les tests JUnit |
| Rapport de tests | Publie les résultats dans l'onglet "Checks" de GitHub |

**Pourquoi c'est important :** Un code qui casse les tests ne passe jamais en production.

---

## 6. Job 2 — Build & Push Docker

**Fichier :** [.github/workflows/deploy.yml](.github/workflows/deploy.yml) — section `build-and-push`

Ce job construit une image Docker de l'application et la pousse sur Docker Hub.

**Prérequis :** Le Job 1 (tests) doit avoir réussi.

**Étapes :**

| Étape | Action |
|---|---|
| Login Docker Hub | Connexion avec les secrets `DOCKERHUB_USERNAME` et `DOCKERHUB_TOKEN` |
| Génération des tags | Tag `latest` + tag par commit SHA (ex: `sha-abc1234`) |
| Setup Buildx | Active le builder multi-plateforme de Docker |
| Build & Push | Compile le Dockerfile et envoie l'image sur Docker Hub |

**Le Dockerfile — build multi-stage :**

```
Stage 1 (builder) : maven:3.9-eclipse-temurin-17
  └── Compile le code source → produit un JAR

Stage 2 (runtime) : eclipse-temurin:17-jre-alpine
  └── Image légère (~200MB) contenant seulement le JAR
```

Cette approche réduit la taille finale de l'image : on ne garde pas Maven ni le JDK complet en production.

**Tags produits :**
- `ton-user/spring-maven:latest` — toujours la dernière version
- `ton-user/spring-maven:sha-abc1234` — version traçable par commit

---

## 7. Job 3 — Déploiement Production

**Fichier :** [.github/workflows/deploy.yml](.github/workflows/deploy.yml) — section `deploy`

Ce job se connecte au serveur via SSH et redémarre l'application avec la nouvelle image Docker.

**Prérequis :** Le Job 2 (build Docker) doit avoir réussi.

**Étapes sur le serveur :**

```bash
# 1. Connexion à Docker Hub
docker login -u $DOCKERHUB_USERNAME

# 2. Arrêt de l'ancien conteneur
docker stop spring-maven-app
docker rm   spring-maven-app

# 3. Téléchargement de la nouvelle image
docker pull ton-user/spring-maven:latest

# 4. Démarrage du nouveau conteneur
docker run -d \
  --name spring-maven-app \
  --restart unless-stopped \
  -p 8080:8080 \
  ton-user/spring-maven:latest

# 5. Vérification
docker ps | grep spring-maven-app
```

**Résultat :** L'application tourne sur le port `8080` du serveur, redémarre automatiquement au reboot.

---

## 8. Configuration des secrets GitHub

Aller sur : **GitHub → ton repo → Settings → Secrets and variables → Actions**

| Secret | Description | Exemple |
|---|---|---|
| `DOCKERHUB_USERNAME` | Ton nom d'utilisateur Docker Hub | `monuser` |
| `DOCKERHUB_TOKEN` | Token d'accès Docker Hub (pas ton mot de passe) | `dckr_pat_xxx` |
| `SERVER_HOST` | Adresse IP ou hostname du serveur | `0.tcp.ngrok.io` |
| `SERVER_USER` | Nom d'utilisateur SSH sur le serveur | `ibouk` |
| `SERVER_SSH_KEY` | Clé SSH privée (contenu complet du fichier) | `-----BEGIN OPENSSH...` |
| `SERVER_PORT` | Port SSH (22 par défaut) | `12345` |
| `DB_URL` | URL de la base de données | `jdbc:h2:mem:testdb` |
| `DB_USER` | Utilisateur base de données | `sa` |
| `DB_PASSWORD` | Mot de passe base de données | *(vide pour H2)* |

**Créer un token Docker Hub :**
1. Se connecter sur hub.docker.com
2. Account Settings → Security → New Access Token
3. Copier le token généré → le coller dans le secret `DOCKERHUB_TOKEN`

---

## 9. Déploiement sur PC personnel (Windows 11)

Pour utiliser ton propre PC comme serveur de déploiement.

### Étape 1 — Activer le serveur SSH (PowerShell Admin)

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'
```

### Étape 2 — Générer la clé SSH (Git Bash)

```bash
# Générer la paire de clés
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions -N ""

# Autoriser la clé sur le PC local
cp ~/.ssh/github_actions.pub ~/.ssh/authorized_keys
```

Corriger les permissions (PowerShell Admin) :
```powershell
icacls "$env:USERPROFILE\.ssh\authorized_keys" /inheritance:r /grant:r "$env:USERNAME:(F)" /grant:r "*S-1-5-18:(F)"
```

Tester la connexion :
```bash
ssh -i ~/.ssh/github_actions localhost
# Doit connecter sans mot de passe
```

### Étape 3 — Exposer le PC avec ngrok

```bash
# Installer ngrok
winget install ngrok

# Configurer ton token (depuis ngrok.com)
ngrok config add-authtoken TON_TOKEN

# Lancer le tunnel SSH
ngrok tcp 22
```

Exemple de sortie :
```
Forwarding  tcp://0.tcp.ngrok.io:12345 -> localhost:22
```

Mettre à jour les secrets GitHub :
- `SERVER_HOST` = `0.tcp.ngrok.io`
- `SERVER_PORT` = `12345`

> **Note :** L'adresse ngrok change à chaque redémarrage (version gratuite). Penser à mettre à jour les secrets après chaque redémarrage de ngrok.

### Étape 4 — Récupérer la clé privée pour GitHub

```bash
cat ~/.ssh/github_actions
```

Copier tout le contenu (de `-----BEGIN OPENSSH PRIVATE KEY-----` jusqu'à `-----END OPENSSH PRIVATE KEY-----`) et le coller dans le secret `SERVER_SSH_KEY`.

---

## 10. Lancer l'application en local

### Avec Maven directement

```bash
mvn spring-boot:run
```

L'application sera accessible sur : `http://localhost:8080`

### Avec Docker

```bash
# Build de l'image
docker build -t spring-maven .

# Lancer le conteneur
docker run -d \
  --name spring-maven-app \
  -p 8080:8080 \
  spring-maven

# Vérifier que ça tourne
docker ps
docker logs spring-maven-app
```

### Vérifier que l'API répond

```bash
curl http://localhost:8080
```

---

## Résumé du flux complet

```
Tu modifies le code
      │
      │  git push origin main
      ▼
GitHub Actions se déclenche automatiquement
      │
      ├─ [Job 1] Tests Maven          → vérifie que le code est correct
      │
      ├─ [Job 2] Build Docker         → crée l'image et la pousse sur Docker Hub
      │
      └─ [Job 3] Déploiement SSH      → redémarre l'appli sur le serveur
                                         avec la nouvelle version
```

Chaque push sur `main` = déploiement automatique si tous les tests passent.
