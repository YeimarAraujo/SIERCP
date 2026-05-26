# SECURITY-ROTATIONS.md

Registro de auditorías de secretos y rotaciones de credenciales del ecosistema SIERCP.

---

## Auditoría inicial — 2026-05-22

### Alcance verificado

Repositorio: `c:\Programacion\SIERCP` (branch: Yeimar)

### Comandos ejecutados

```bash
# 1. Verificar que .env.local nunca fue commiteado
git log --all -p -- ".env.local" "SIERCP-WEB/.env.local" "**/.env.local"
# Resultado: OUTPUT VACÍO ✅ — nunca fue commiteado

# 2. Verificar que ningún secreto está tracked en el repo
git grep -rE "(WOMPI_PRIVATE_KEY|FIREBASE_ADMIN_KEY|prv_test_|prv_prod_|service_account)" \
  -- ":(exclude)*.md" ":(exclude)*.example" ":(exclude)*.gitignore"
# Resultado: OUTPUT VACÍO ✅ — ningún secreto en archivos versionados

# 3. Verificar .gitignore en los tres proyectos
cat .gitignore             # Raíz: incluye .env.local ✅
cat SIERCP-WEB/.gitignore  # Incluye .env.local, .env.*.local ✅
# siercp_flutter/functions/.gitignore: NO EXISTÍA → creado en esta auditoría ✅
```

### Estado de las credenciales

| Credencial | ¿Commiteada? | Estado | Acción requerida |
|---|---|---|---|
| `FIREBASE_ADMIN_KEY` | ❌ No | Solo en `.env.local` local | Ninguna |
| `NEXT_PUBLIC_FIREBASE_API_KEY` | ❌ No | Solo en `.env.local` local | Ninguna (es pública por diseño) |
| `WOMPI_PRIVATE_KEY` | ❌ No | Solo en `.env.local` local | Ninguna |
| `WOMPI_INTEGRITY_KEY` | ❌ No | Solo en `.env.local` local | Ninguna |
| `WOMPI_EVENTS_SECRET` | ❌ No | Solo en `.env.local` local | Ninguna |
| `scripts/service-account.json` | ❌ No | En `.gitignore` de raíz ✅ | Ninguna |

### Veredicto

**LIMPIO** — ningún secreto fue commiteado en la historia del repositorio.

---

## Mejoras aplicadas en esta auditoría

- Creado `siercp_flutter/functions/.gitignore` (faltaba).
- Reforzado el patrón en `.gitignore` raíz para incluir todos los patrones `*.env*`.
- Verificado que `SIERCP-WEB/.gitignore` cubre `.env`, `.env.local`, `.env.*.local`.

---

## Proceso para rotación futura

Si en el futuro se detecta que un secreto fue expuesto:

### 1. Rotar Firebase Admin Service Account
```bash
# En Firebase Console → Project Settings → Service Accounts
# → Generate new private key
# Actualizar FIREBASE_ADMIN_KEY en el hosting (Vercel/Cloud Run)
# Revocar la key anterior
```

### 2. Rotar Wompi Keys
```bash
# En dashboard.wompi.co → Configuración → Llaves de API
# Generar nuevas llaves sandbox/producción
# Actualizar en variables de entorno del servidor
# NUNCA commit de llaves nuevas
```

### 3. Rotar Firebase API Keys (client-side)
```bash
# En Firebase Console → Project Settings → General → Web API Key
# Nota: las API keys de Firebase son restringibles por dominio, no son secretos críticos
# Pero si se exponen con datos de prod, actualizar HTTP referrer restrictions
```

### 4. Documentar aquí con fecha y motivo
```
## Rotación YYYY-MM-DD
**Motivo:** [Descripción]
**Credenciales rotadas:** [Lista]
**Rotado por:** [Persona]
**Verificado por:** [Persona]
```

---

## Pendientes para mayor seguridad (recomendaciones)

- [ ] Migrar `FIREBASE_ADMIN_KEY` a **Firebase Secret Manager** para Cloud Functions.
- [ ] Configurar **Vercel Environment Variables** con `Sensitive` flag para producción.
- [ ] Agregar `npm audit --production` al pipeline CI antes de cada deploy.
- [ ] Configurar alertas de Firebase para detectos de uso anómalo de credenciales.
- [ ] Crear `.env.example` con keys vacías como referencia para nuevos developers.
