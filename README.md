# BioRuta GPS-G7
**Solución Integral de Transporte Estudiantil Universitario**

Proyecto desarrollado para la asignatura de Gestión de Proyectos de Software del primer semestre 2025, Universidad del Bío Bío.

<img width="128" alt="BioLogo" src="https://github.com/user-attachments/assets/4780cda8-801e-48c8-bc65-76d0ef1f41eb">

## 📋 Descripción del Proyecto

BioRuta es una aplicación móvil innovadora diseñada para optimizar el transporte estudiantil en la Universidad del Bío Bío. La plataforma conecta conductores y pasajeros de manera segura y eficiente, promoviendo la movilidad sostenible y reduciendo costos de transporte para la comunidad universitaria.

## 🚀 Características Principales

### 👥 Sistema de Usuarios
- **Registro y autenticación** con validación universitaria
- **Perfiles completos** con información de contacto y emergencia
- **Sistema de amistades** para construir redes de confianza
- **Ranking de usuarios** basado en calificaciones y comportamiento

### 🗺️ Gestión de Viajes
- **Publicación de viajes** con origen, destino y detalles
- **Búsqueda avanzada** por ubicación, fecha y precio
- **Solicitudes de unión** con sistema de aprobación
- **Tracking en tiempo real** durante el viaje
- **Historial completo** de viajes realizados

### 💬 Comunicación Integrada
- **Chat grupal** para coordinación de viajes
- **Chat personal** entre usuarios
- **Notificaciones push** para eventos importantes
- **Sistema de mensajería** en tiempo real

### 🔒 Seguridad y Confianza
- **Verificación universitaria** obligatoria
- **Contactos de emergencia** configurables
- **Sistema SOS** con alertas automáticas
- **Calificaciones y comentarios** post-viaje

### 💳 Gestión Financiera
- **Cálculo automático** de costos compartidos
- **Historial de transacciones** detallado
- **Diferentes métodos de pago** disponibles

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
- **OpenStreetMap**: Mapas y geolocalización
- **Nominatum¨**: Sugerencias de lugares

### DevOps y Deployment
- **Git**: Control de versiones
- **GitHub**: Repositorio y colaboración

## 📱 Funcionalidades por Módulo

### Autenticación y Perfiles
- ✅ Registro con validación de correo universitario
- ✅ Login seguro con JWT
- ✅ Gestión de perfiles personales
- ✅ Configuración de contactos de emergencia
- ✅ Sistema de verificación de identidad

### Gestión de Amistades
- ✅ Envío y recepción de solicitudes
- ✅ Administración de lista de amigos
- ✅ Sistema de notificaciones para solicitudes
- ✅ Búsqueda de usuarios por RUT/nombre

### Publicación y Búsqueda de Viajes
- ✅ Crear viajes con detalles completos
- ✅ Búsqueda geográfica avanzada
- ✅ Filtros por fecha, precio y disponibilidad
- ✅ Vista de mapa interactiva
- ✅ Gestión de solicitudes de pasajeros

### Comunicación
- ✅ Chat grupal por viaje
- ✅ Chat personal entre usuarios
- ✅ Notificaciones push en tiempo real
- ✅ Historial de conversaciones

### Seguridad
- ✅ Botón SOS con alertas automáticas
- ✅ Contactos de emergencia configurables
- ✅ Sistema de reporte de usuarios
- ✅ Moderación de contenido

### Pagos y Finanzas
- 🔄 Integración con WebPay (en desarrollo)
- 🔄 Cálculo automático de costos
- 🔄 Historial de transacciones
- 🔄 Sistema de reembolsos

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
│   │   ├── mapa/            # Módulo de mapas y geolocalización
│   │   ├── viajes/          # Gestión de viajes
│   │   ├── chat/            # Sistema de mensajería
│   │   ├── perfil/          # Gestión de perfiles
│   │   ├── services/        # Servicios API y WebSocket
│   │   ├── widgets/         # Componentes reutilizables
│   │   └── utils/           # Utilidades y helpers
│   ├── android/             # Configuración Android
│   ├── ios/                 # Configuración iOS
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

## 🏆 Reconocimientos

Este proyecto representa el esfuerzo colaborativo de un equipo multidisciplinario comprometido con la innovación en movilidad estudiantil y el desarrollo de software de calidad empresarial.

**Universidad del Bío Bío - Facultad de Ciencias Empresariales** 
**Gestión de Proyectos de software** 
**Ingeniería Civil en Informática - 2025**

---

## 👨‍💻 EQUIPO

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/JoMULLOA">
        <img src="https://avatars.githubusercontent.com/JoMULLOA" width="100px;" alt="JoMULLOA"/>
        <br />
        <sub><b>José Manríquez</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/Joaqomv">
        <img src="https://avatars.githubusercontent.com/Joaqomv" width="100px;" alt="Joaqomv"/>
        <br />
        <sub><b>Joaquin Maureira</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/KrozJGG">
        <img src="https://avatars.githubusercontent.com/KrozJGG" width="100px;" alt="KrozJGG"/>
        <br />
        <sub><b>Christian Jamett</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/lu1spereir4">
        <img src="https://avatars.githubusercontent.com/lu1spereir4" width="100px;" alt="lu1spereir4"/>
        <br />
        <sub><b>Luis Pereira</b></sub>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/Sternen-prince">
        <img src="https://avatars.githubusercontent.com/Sternen-prince" width="100px;" alt="Sternen-prince"/>
        <br />
        <sub><b>Francisco Cisterna</b></sub>
      </a>
    </td>
  </tr>
</table>

## 🏅 Roles y Responsabilidades

<table>
  <tr>
    <th>Integrante</th>
    <th>Rol Principal</th>
    <th>Especialización</th>
    <th>Contribuciones Clave</th>
  </tr>
  <tr>
    <td><strong>José Manríquez</strong></td>
    <td>Project Manager & Full-Stack Developer</td>
    <td>Arquitectura y Liderazgo</td>
    <td>Diseño de arquitectura, gestión de proyecto, integración de módulos</td>
  </tr>
  <tr>
    <td><strong>Joaquín Maureira</strong></td>
    <td>Backend Developer</td>
    <td>APIs y Base de Datos</td>
    <td>Desarrollo de APIs REST, gestión de BD, sistema de autenticación</td>
  </tr>
  <tr>
    <td><strong>Christian Jamett</strong></td>
    <td>Frontend Developer</td>
    <td>UI/UX y Flutter</td>
    <td>Interfaces de usuario, componentes Flutter, experiencia móvil</td>
  </tr>
  <tr>
    <td><strong>Luis Pereira</strong></td>
    <td>Backend Developer</td>
    <td>WebSockets y Real-time</td>
    <td>Sistema de mensajería, notificaciones en tiempo real, chat</td>
  </tr>
  <tr>
    <td><strong>Francisco Cisterna</strong></td>
    <td>QA Engineer & Documentation</td>
    <td>Testing y Documentación</td>
    <td>Pruebas de calidad, documentación técnica, casos de uso</td>
  </tr>
</table>

## 📜 Licencia y Términos

**BioRuta** es un proyecto académico desarrollado bajo supervisión universitaria. El código fuente está disponible para fines educativos y de investigación.

### Derechos de Autor
© 2025 - Equipo GPS-G7, Universidad del Bío Bío. Todos los derechos reservados.

### Términos de Uso Académico
- ✅ Uso para investigación y educación
- ✅ Referencia y citación permitida
- ✅ Contribuciones de la comunidad bienvenidas
- ❌ Uso comercial sin autorización

---

<div align="center">
  <h3>🎓 Universidad del Bío Bío - 2025</h3>
  <p><em>"Innovando en movilidad estudiantil para una universidad más conectada"</em></p>
  
  [![GitHub Stars](https://img.shields.io/github/stars/JoMULLOA/BioRuta?style=social)](https://github.com/JoMULLOA/BioRuta)
  [![GitHub Forks](https://img.shields.io/github/forks/JoMULLOA/BioRuta?style=social)](https://github.com/JoMULLOA/BioRuta)
  [![GitHub Issues](https://img.shields.io/github/issues/JoMULLOA/BioRuta)](https://github.com/JoMULLOA/BioRuta/issues)
  [![GitHub License](https://img.shields.io/github/license/JoMULLOA/BioRuta)](https://github.com/JoMULLOA/BioRuta/blob/main/LICENSE)
</div>
