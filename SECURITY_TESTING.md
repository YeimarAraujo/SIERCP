# SIERCP — Plan de Testing de Seguridad a Nivel de Software

**Sistema Integrado de Evaluación y Retroalimentación de RCP**  
Versión 2.1.0 | Clasificación: Confidencial

---

## Tabla de Contenido

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Superficie de Ataque](#2-superficie-de-ataque)
3. [Pruebas de Autenticación y Autorización](#3-pruebas-de-autenticación-y-autorización)
4. [Pruebas de Inyección](#4-pruebas-de-inyección)
5. [Pruebas de Control de Acceso (RBAC)](#5-pruebas-de-control-de-acceso-rbac)
6. [Pruebas de Rate Limiting](#6-pruebas-de-rate-limiting)
7. [Pruebas de Validación de Entrada](#7-pruebas-de-validación-de-entrada)
8. [Pruebas de Seguridad del Endpoint IoT](#8-pruebas-de-seguridad-del-endpoint-iot)
9. [Pruebas de Tokens JWT](#9-pruebas-de-tokens-jwt)
10. [Comandos de Prueba (Automatizables)](#10-comandos-de-prueba-automatizables)
11. [Checklist de Seguridad](#11-checklist-de-seguridad)
12. [Recomendaciones Adicionales](#12-recomendaciones-adicionales)

---

## 1. Resumen Ejecutivo

El sistema SIERCP expone una API REST sobre HTTP/HTTPS con autenticación JWT. La seguridad se centra en:
- Autenticación robusta con JWT + blacklist
- Control de acceso granular por rol (RBAC)
- Validación estricta de entradas
- Throttling para prevenir brute force

**Herramientas recomendadas para las pruebas:**
- [curl](https://curl.se/) — pruebas manuales de API
- [OWASP ZAP](https://www.zaproxy.org/) — scanner automático
- [Burp Suite Community](https://portswigger.net/burp) — proxy de intercepción
- `pytest` + `rest_framework.test` — pruebas unitarias Django

---

## 2. Superficie de Ataque

| Endpoint | Autenticación | Riesgo |
|---|---|---|
| `POST /api/auth/login/` | Ninguna | Brute force |
| `POST /api/auth/register/` | Ninguna | Registro spam, IDOR |
| `POST /api/data/recibir/` | API Key (`X-API-Key`) | Inyección de datos falsos |
| `GET /api/users/` | JWT + ADMIN | Enumeración de usuarios |
| `DELETE /api/users/{id}/` | JWT + ADMIN | Eliminación no autorizada |
| `GET /api/sessions/` | JWT | Data leakage entre usuarios |
| WebSocket `/ws/session/{id}/` | JWT por query param | Token exposure en logs |

---

## 3. Pruebas de Autenticación y Autorización

### TEST-AUTH-01: Acceso sin token
```bash
# ESPERADO: 401 Unauthorized
curl -X GET http://localhost:8000/api/users/

# ESPERADO: 401 Unauthorized
curl -X GET http://localhost:8000/api/sessions/

# ESPERADO: 200 OK (público)
curl -X GET http://localhost:8000/api/test/
```

### TEST-AUTH-02: Token inválido/expirado
```bash
# ESPERADO: 401 Unauthorized
curl -X GET http://localhost:8000/api/users/ \
  -H "Authorization: Bearer token_invalido_aqui"

# ESPERADO: 401 Unauthorized con token manipulado
curl -X GET http://localhost:8000/api/sessions/ \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MX0.FIRMA_FALSA"
```

### TEST-AUTH-03: Logout y reutilización de token
```bash
# 1. Login
TOKEN=$(curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"estudiante1","password":"test1234"}' | python -c "import sys,json; print(json.load(sys.stdin)['access'])")

REFRESH=$(curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"estudiante1","password":"test1234"}' | python -c "import sys,json; print(json.load(sys.stdin)['refresh'])")

# 2. Logout (blacklist)
curl -X POST http://localhost:8000/api/auth/logout/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"refresh\": \"$REFRESH\"}"

# 3. Intentar usar el refresh token después del logout
# ESPERADO: 401 Token is blacklisted
curl -X POST http://localhost:8000/api/auth/refresh/ \
  -H "Content-Type: application/json" \
  -d "{\"refresh\": \"$REFRESH\"}"
```

### TEST-AUTH-04: Login por email
```bash
# ESPERADO: 200 con tokens (si el email existe)
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "usuario@example.com", "password": "test1234"}'
```

---

## 4. Pruebas de Inyección

### TEST-INJ-01: SQL Injection en login
```bash
# Intentar bypass de autenticación con SQL injection
# ESPERADO: 401 (Django ORM usa consultas parametrizadas — inmune a SQL injection)
curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "admin'\''--", "password": "cualquier_cosa"}'

curl -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "admin\" OR \"1\"=\"1", "password": "test"}'
```

### TEST-INJ-02: XSS en campos de texto
```bash
# ESPERADO: Datos guardados como string literal, nunca ejecutados
# (DRF serializa JSON puro, no HTML)
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test_xss",
    "password": "test12345",
    "email": "xss@test.com",
    "first_name": "<script>alert(1)</script>",
    "last_name": "Test",
    "rol": "ESTUDIANTE"
  }'
```

### TEST-INJ-03: Path Traversal en IDs
```bash
# ESPERADO: 400/404, nunca acceso a archivos del sistema
curl -X GET "http://localhost:8000/api/sessions/../../../etc/passwd" \
  -H "Authorization: Bearer $TOKEN"

curl -X GET "http://localhost:8000/api/users/%2F%2F%2F" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## 5. Pruebas de Control de Acceso (RBAC)

### TEST-RBAC-01: Estudiante intenta acceder a endpoints de Admin
```bash
# ESTUDIANTE intenta listar usuarios
# ESPERADO: 403 Forbidden
curl -X GET http://localhost:8000/api/users/ \
  -H "Authorization: Bearer $ESTUDIANTE_TOKEN"

# ESTUDIANTE intenta eliminar un usuario
# ESPERADO: 403 Forbidden
curl -X DELETE http://localhost:8000/api/users/1/ \
  -H "Authorization: Bearer $ESTUDIANTE_TOKEN"
```

### TEST-RBAC-02: Estudiante intenta crear curso
```bash
# ESPERADO: 403 Forbidden
curl -X POST http://localhost:8000/api/courses/ \
  -H "Authorization: Bearer $ESTUDIANTE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"nombre": "Curso Trampa", "descripcion": "No debería crearse"}'
```

### TEST-RBAC-03: Instructor intenta ver sesiones de otro instructor
```bash
# Instructor A busca sesiones del Instructor B
# ESPERADO: Solo ve las de sus cursos, no las de otro instructor
curl -X GET http://localhost:8000/api/sessions/ \
  -H "Authorization: Bearer $INSTRUCTOR_A_TOKEN"
```

### TEST-RBAC-04: Estudiante intenta ver sesiones de otro estudiante
```bash
# ESPERADO: Solo ve sus propias sesiones
curl -X GET http://localhost:8000/api/sessions/ \
  -H "Authorization: Bearer $ESTUDIANTE_TOKEN"

# ESPERADO: 403 o 404 si intenta acceder directamente al ID de otro
curl -X GET http://localhost:8000/api/sessions/99999/ \
  -H "Authorization: Bearer $ESTUDIANTE_TOKEN"
```

### TEST-RBAC-05: Instructor intenta enrolar en curso ajeno
```bash
# ESPERADO: 403 Forbidden
curl -X POST http://localhost:8000/api/courses/99/enroll/ \
  -H "Authorization: Bearer $INSTRUCTOR_B_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"identificacion": "12345678"}'
```

### TEST-RBAC-06: Admin se intenta auto-eliminar
```bash
# ESPERADO: 400 Bad Request con mensaje "No puedes eliminar tu propia cuenta"
curl -X DELETE http://localhost:8000/api/users/$ADMIN_ID/ \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## 6. Pruebas de Rate Limiting

### TEST-RATE-01: Brute force en login
```bash
# Enviar 35+ requests en un minuto (límite: 30/min para anónimos)
# ESPERADO: A partir del request 31, respuesta 429 Too Many Requests

for i in $(seq 1 35); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST http://localhost:8000/api/auth/login/ \
    -H "Content-Type: application/json" \
    -d '{"username":"noexiste","password":"noexiste"}')
  echo "Request $i: HTTP $STATUS"
  sleep 0.1
done
```

### TEST-RATE-02: Rate limit para usuarios autenticados
```bash
# Enviar 205+ requests en un minuto (límite: 200/min para usuarios)
# ESPERADO: Request 201+ → 429 Too Many Requests
for i in $(seq 1 205); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    http://localhost:8000/api/auth/me/)
  echo "Request $i: HTTP $STATUS"
done
```

---

## 7. Pruebas de Validación de Entrada

### TEST-VAL-01: Registro con email duplicado
```bash
# ESPERADO: 400 "Ya existe un usuario con ese email"
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"nuevo_user","password":"test12345","email":"admin@siercp.edu","first_name":"Test","last_name":"User","rol":"ESTUDIANTE"}'
```

### TEST-VAL-02: Registro con contraseña corta
```bash
# ESPERADO: 400 (min_length = 8)
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser2","password":"123","email":"t2@test.com","first_name":"Test","last_name":"User","rol":"ESTUDIANTE"}'
```

### TEST-VAL-03: Cédula duplicada
```bash
# ESPERADO: 400 "Ya existe un usuario con esa identificación"
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"user3","password":"test12345","email":"user3@test.com","first_name":"Test","last_name":"User","rol":"ESTUDIANTE","identificacion":"12345678"}'
```

### TEST-VAL-04: Registro con rol inválido
```bash
# ESPERADO: 400 "Not a valid choice"
curl -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"hacker","password":"test12345","email":"h@h.com","first_name":"H","last_name":"H","rol":"SUPERADMIN"}'
```

### TEST-VAL-05: Datos del sensor con valores extremos
```bash
# ESPERADO: 200 (el sistema guarda los datos y evalúa el nivel)
curl -X POST http://localhost:8000/api/data/recibir/ \
  -H "Content-Type: application/json" \
  -d '{"maniqui_uuid":"AA:BB:CC:DD:EE:FF","ritmo_cardiaco":999.9,"oxigeno":-1,"presion":9999,"temperatura":100}'
```

---

El endpoint `/api/data/recibir/` requiere una `X-API-Key` válida enviada en el header para procesar los datos.

### TEST-IOT-01: Envío sin API Key
```bash
# ESPERADO: 403 Forbidden (Missing API Key)
curl -X POST http://localhost:8000/api/data/recibir/ \
  -H "Content-Type: application/json" \
  -d '{"maniqui_uuid":"AA:BB:CC:DD:EE:FF","ritmo_cardiaco":75.0,"oxigeno":98.0,"presion":120.0,"temperatura":36.5}'
```

### TEST-IOT-02: Envío con API Key inválida
```bash
# ESPERADO: 403 Forbidden (Invalid API Key)
curl -X POST http://localhost:8000/api/data/recibir/ \
  -H "Content-Type: application/json" \
  -H "X-API-Key: clave_falsa" \
  -d '{"maniqui_uuid":"AA:BB:CC:DD:EE:FF","ritmo_cardiaco":75.0,"oxigeno":98.0,"presion":120.0,"temperatura":36.5}'
```

### TEST-IOT-03: Envío correcto con API Key
```bash
# ESPERADO: 200 OK
curl -X POST http://localhost:8000/api/data/recibir/ \
  -H "Content-Type: application/json" \
  -H "X-API-Key: siercp_key_XXXXX" \
  -d '{"maniqui_uuid":"AA:BB:CC:DD:EE:FF","ritmo_cardiaco":75.0,"oxigeno":98.0,"presion":120.0,"temperatura":36.5}'
```

---

## 9. Pruebas de Tokens JWT

### TEST-JWT-01: Manipulación del payload del token
```bash
# Intentar cambiar el user_id en el payload sin firma válida
# ESPERADO: 401 (firma inválida)
FAKE_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxfQ.FIRMA_FALSA"
curl -X GET http://localhost:8000/api/auth/me/ \
  -H "Authorization: Bearer $FAKE_TOKEN"
```

### TEST-JWT-02: Token de algoritmo "none"
```bash
# Intentar el ataque "alg:none" — omitir firma
# ESPERADO: 401 (Django SimpleJWT rechaza alg:none)
NONE_TOKEN="eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJ1c2VyX2lkIjoxfQ."
curl -X GET http://localhost:8000/api/auth/me/ \
  -H "Authorization: Bearer $NONE_TOKEN"
```

### TEST-JWT-03: Verificar que el token expira
```bash
# Access token: 2 horas de vida
# Usar un token generado hace más de 2 horas
# ESPERADO: 401 Token is expired

# Para pruebas rápidas, reducir temporalmente en settings.py:
# 'ACCESS_TOKEN_LIFETIME': timedelta(seconds=5)
```

### TEST-JWT-04: Rotación de refresh token
```bash
# 1. Obtener tokens
RESP=$(curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"tu_contraseña"}')

REFRESH=$(echo $RESP | python -c "import sys,json; print(json.load(sys.stdin)['refresh'])")

# 2. Usar el refresh para obtener nuevo access
NEW_ACCESS=$(curl -s -X POST http://localhost:8000/api/auth/refresh/ \
  -H "Content-Type: application/json" \
  -d "{\"refresh\": \"$REFRESH\"}" | python -c "import sys,json; print(json.load(sys.stdin)['access'])")

# 3. Intentar reusar el refresh anterior
# ESPERADO: 401 Token is blacklisted (BLACKLIST_AFTER_ROTATION = True)
curl -X POST http://localhost:8000/api/auth/refresh/ \
  -H "Content-Type: application/json" \
  -d "{\"refresh\": \"$REFRESH\"}"
```

---

## 10. Comandos de Prueba (Automatizables)

### Script de prueba rápida (bash)

```bash
#!/bin/bash
# siercp_security_test.sh
BASE_URL="http://localhost:8000/api"
echo "========================================"
echo " SIERCP Security Test Suite"
echo "========================================"

# Test 1: Health Check
echo -n "[TEST-01] Health check... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/test/)
[ "$STATUS" = "200" ] && echo "✅ PASS" || echo "❌ FAIL (got $STATUS)"

# Test 2: Protected endpoint sin token
echo -n "[TEST-02] Protected endpoint sin auth... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/users/)
[ "$STATUS" = "401" ] && echo "✅ PASS" || echo "❌ FAIL (got $STATUS)"

# Test 3: Login inválido
echo -n "[TEST-03] Login con credenciales inválidas... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST $BASE_URL/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"noexiste","password":"noexiste"}')
[ "$STATUS" = "401" ] && echo "✅ PASS" || echo "❌ FAIL (got $STATUS)"

# Test 4: Registro con email duplicado (ajustar si no existe el email)
echo -n "[TEST-04] Registro con datos inválidos... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST $BASE_URL/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"x","password":"123","email":"bad_email","first_name":"","last_name":"","rol":"ADMIN_HACK"}')
[ "$STATUS" = "400" ] && echo "✅ PASS" || echo "❌ FAIL (got $STATUS)"

# Test 5: IoT endpoint con API Key
echo -n "[TEST-05] IoT endpoint acepta datos con API Key... "
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST $BASE_URL/data/recibir/ \
  -H "Content-Type: application/json" \
  -H "X-API-Key: siercp_key_XXXXX" \
  -d '{"maniqui_uuid":"TEST","ritmo_cardiaco":75,"oxigeno":98,"presion":120,"temperatura":36}')
[ "$STATUS" = "200" ] && echo "✅ PASS" || echo "❌ FAIL (got $STATUS)"

echo "========================================"
echo " Tests completados"
echo "========================================"
```

### Prueba con Django Test Client (Python)

```python
# tests/test_security.py
from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status

class SecurityTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_superuser('admin', 'admin@test.com', 'admin12345')
        self.student = User.objects.create_user('student1', 'student@test.com', 'student12345')
        from api.models import Perfil
        Perfil.objects.create(user=self.student, rol='ESTUDIANTE', identificacion='11111111')

    def test_protected_endpoint_requires_auth(self):
        """Endpoints protegidos deben retornar 401 sin token."""
        response = self.client.get('/api/users/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_student_cannot_list_users(self):
        """Estudiante no puede ver lista de todos los usuarios."""
        self.client.force_authenticate(user=self.student)
        response = self.client.get('/api/users/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_student_cannot_create_course(self):
        """Estudiante no puede crear cursos."""
        self.client.force_authenticate(user=self.student)
        response = self.client.post('/api/courses/', {
            'nombre': 'Curso Trampa',
            'descripcion': 'No debería crearse'
        })
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_iot_endpoint_is_public(self):
        """El endpoint IoT debe aceptar datos sin token."""
        response = self.client.post('/api/data/recibir/', {
            'maniqui_uuid': 'TEST-UUID',
            'ritmo_cardiaco': 75.0,
            'oxigeno': 98.0,
            'presion': 120.0,
            'temperatura': 36.5
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_admin_cannot_delete_self(self):
        """Admin no puede eliminarse a sí mismo."""
        self.client.force_authenticate(user=self.admin)
        response = self.client.delete(f'/api/users/{self.admin.id}/')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_health_check_public(self):
        """Health check debe ser accesible sin autenticación."""
        response = self.client.get('/api/test/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
```

---

## 11. Checklist de Seguridad

### Autenticación
- [x] JWT con expiración configurada (2h access, 14d refresh)
- [x] Blacklist de refresh tokens al hacer logout
- [x] Rotación automática de refresh tokens
- [x] Login por username o email
- [x] Contraseña con mínimo 8 caracteres

### Control de Acceso
- [x] RBAC: ADMIN / INSTRUCTOR / ESTUDIANTE con permisos granulares
- [x] Admin no puede eliminarse a sí mismo
- [x] Instructor solo gestiona sus propios cursos
- [x] Estudiante solo ve sus propias sesiones
- [x] Superusuarios mapeados al rol ADMIN

### Rate Limiting
- [x] 30 req/min para usuarios anónimos
- [x] 200 req/min para usuarios autenticados

### Validación de Datos
- [x] Email único por usuario
- [x] Identificación (cédula) única por usuario
- [x] Rol validado con choicefield (no acepta values arbitrarios)
- [x] Serializers con validación de tipos

### Seguridad de Red
- [x] CORS configurado (permissive en dev, restrictivo en prod)
- [x] HSTS en producción
- [x] X-Frame-Options: DENY en producción
- [x] XSS Filter en producción
- [x] CSRF protections en sesiones Django

### IoT / ESP-32
- [x] Endpoint IoT protegido por **X-API-Key** (seguridad por dispositivo)
- [x] Rate limiting protege también el endpoint IoT
- [x] UUID del maniquí verificado (graceful si no existe)
- [ ] **PENDIENTE**: HTTPS en producción para encriptar datos del sensor

---

## 12. Recomendaciones Adicionales

### Prioridad Alta
1. **HTTPS**: En producción, usar HTTPS (nginx + certbot/Let's Encrypt). Nunca enviar datos médicos/JWT por HTTP plano.
2. **API Key para IoT**: Añadir un campo `api_key` al modelo `Maniqui` y validarlo en `/api/data/recibir/` para evitar inyección de datos falsos desde dispositivos no registrados.
3. **Logging de acceso**: Registrar todos los intentos de autenticación fallidos con IP y timestamp.

### Prioridad Media
4. **2FA para Admin**: Implementar autenticación de dos factores para cuentas con rol ADMIN.
5. **Auditoría**: Añadir un modelo `AuditLog` que registre quién eliminó usuarios, cambió roles o accedió a datos sensibles.
6. **WebSocket Auth**: El token JWT se envía como query param en el WebSocket — considerar mejorar a cookie HttpOnly en producción.

### Prioridad Baja
7. **CAPTCHA**: En el endpoint de registro para evitar creación masiva de cuentas.
8. **Caducidad de sesiones inactivas**: Invalidar tokens si el usuario no ha hecho requests en N horas.
9. **Paginación**: Todos los endpoints de listado deben paginarse para evitar dumps masivos de datos.
