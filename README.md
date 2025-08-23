# Rugby The Wessex School
**Solución Integral de la Gestión de la Rama de Rugby**

Proyecto desarrollado para proyecto de titulo en el año 2025, Universidad del Bío Bío.

## 📋 Descripción del Proyecto

## 🚀 Características Principales

## 🛠️ Arquitectura Tecnológica

### Frontend
- **Flutter**: Framework multiplataforma para desarrollo móvil
- **Dart**: Lenguaje de programación principal
- **Android Studio**: Entorno de desarrollo integrado
- **Material Design**: Sistema de diseño para UI/UX consistente

### Backend
- **Node.js**: Runtime de JavaScript del lado servidor
- **Express.js**: Framework web minimalista y flexible
- **Socket.io**: Comunicación en tiempo real
- **JWT**: Autenticación basada en tokens

### Base de Datos
- **PostgreSQL**: Sistema de gestión de base de datos relacional
- **MongoDB**: Sistema de gestión NOSQL 
- **TypeORM**: ORM para manejo de entidades y relaciones
- **Migraciones**: Control de versiones de esquema de BD

### APIs y Servicios Externos

### DevOps y Deployment
- **Git**: Control de versiones
- **GitHub**: Repositorio y colaboración

## 📱 Funcionalidades por Módulo

## 🏗️ Estructura del Proyecto

```
BioRuta/
├── backend/                 # Servidor Node.js + Express
│   ├── src/
│   │   ├── controllers/     # Lógica de controladores
│   │   ├── entities/        # Modelos de base de datos
│   │   ├── routes/          # Definición de rutas API
│   │   ├── services/        # Lógica de negocio
│   │   ├── middlewares/     # Middlewares personalizados
│   │   ├── config/          # Configuraciones del sistema
│   │   └── utils/           # Utilidades generales
│   └── package.json         # Dependencias backend
│
├── frontend/                # Aplicación Flutter
│   ├── lib/
│   │   ├── auth/            # Módulo de autenticación
│   │   ├── chat/            # Sistema de mensajería
│   │   ├── perfil/          # Gestión de perfiles
│   │   ├── services/        # Servicios API y WebSocket
│   │   ├── widgets/         # Componentes reutilizables
│   │   └── utils/           # Utilidades y helpers
│   └── pubspec.yaml         # Dependencias Flutter
│
└── README.md                # Documentación del proyecto
```

## 🔧 Configuración y Desarrollo

### Prerrequisitos
- **Node.js** (v16 o superior)
- **Flutter SDK** (v3.0 o superior)
- **PostgreSQL** (v12 o superior)
- **Android Studio** y **VS Code**
- **Git** para control de versiones

### Instalación Backend
```bash
cd backend/
npm install
npm run dev
```

### Instalación Frontend
```bash
cd frontend/
flutter pub get
flutter run
```

**Universidad del Bío Bío - Facultad de Ciencias Empresariales** 
**Proyecto de Título** 
**Ingeniería Civil en Informática - 2025**

---

## 🏅 Roles y Responsabilidades

<table>
  <tr>
    <th>Foto</th>
    <th>Integrante</th>
    <th>Rol Principal</th>
    <th>Especialización</th>
    <th>Contribuciones Clave</th>
  </tr>
  <tr>
    <td align="center">
      <img src="https://avatars.githubusercontent.com/JoMULLOA" width="60px;" alt="JoMULLOA"/>
    </td>
    <td><a href="https://github.com/JoMULLOA"><strong>José Manríquez</strong></a></td>
    <td>Software Engineer</td>
    <td>Análisis, evaluación y desarrollo del proyecto</td>
    <td>
      Desarrollo de informe de proyecto, login/logout
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="https://avatars.githubusercontent.com/lu1spereir4" width="60px;" alt="lu1spereir4"/>
    </td>
    <td><a href="https://github.com/lu1spereir4"><strong>Luis Pereira</strong></a></td>
    <td>Software Engineer</td>
    <td>Análisis, evaluación y desarrollo del proyecto</td>
    <td>
      Desarrollo de informe de proyecto
    </td>
  </tr>
</table>