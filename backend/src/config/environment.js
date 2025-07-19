/**
 * 🌍 Configuración de Entornos para BioRuta
 * 
 * Flujo simplificado:
 * - base/test: Desarrollo y testing local
 * - main: Producción en servidor automático
 */

const environments = {
  development: {
    // Para ramas 'base' y 'test' - desarrollo local
    app: {
      name: 'BioRuta Local',
      port: process.env.PORT || 3000,
      baseUrl: 'http://localhost:3000',
      frontendUrl: 'http://10.0.2.2:3000', // Android Studio
    },
    
    // MongoDB Atlas para desarrollo local
    database: {
      mongodb: process.env.MONGO_URI || 'mongodb+srv://admin:root@biorutamongo.tphgmlc.mongodb.net/bioruta?retryWrites=true&w=majority',
      options: {
        useNewUrlParser: true,
        useUnifiedTopology: true,
      }
    },
    
    // CORS permisivo para desarrollo
    cors: {
      origin: ['http://localhost:8080', 'http://10.0.2.2:3000', 'http://127.0.0.1:8080'],
      credentials: true,
    },
    
    // Logs detallados en desarrollo
    logging: {
      level: 'debug',
      requests: true,
      errors: true,
    },
    
    // JWT con tiempo largo para desarrollo
    jwt: {
      secret: process.env.ACCESS_TOKEN_SECRET || 'dev-secret-change-in-production',
      expiresIn: '7d', // 7 días en desarrollo
    }
  },

  production: {
    // Para rama 'main' - servidor de producción
    app: {
      name: 'BioRuta Production',
      port: process.env.PORT || 80, // Puerto del servidor
      baseUrl: `http://${process.env.HOST || '146.83.198.35'}:1245`,
      frontendUrl: `http://${process.env.HOST || '146.83.198.35'}:1245`,
    },
    
    // MongoDB local en el servidor (no Atlas)
    database: {
      mongodb: process.env.MONGO_PROD_URI || `mongodb://adminuser:jmaureira@146.83.198.35:1250/admin`,
      options: {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        maxPoolSize: 10,
        serverSelectionTimeoutMS: 5000,
        socketTimeoutMS: 45000,
      }
    },
    
    // CORS restrictivo para producción
    cors: {
      origin: [`http://${process.env.HOST || '146.83.198.35'}:1245`],
      credentials: true,
    },
    
    // Logs mínimos en producción
    logging: {
      level: 'warn',
      requests: false,
      errors: true,
    },
    
    // JWT con tiempo corto para producción
    jwt: {
      secret: process.env.ACCESS_TOKEN_SECRET,
      expiresIn: '24h', // 24 horas en producción
    },
    
    // Configuraciones adicionales para producción
    email: {
      user: process.env.GMAIL_USER,
      pass: process.env.GMAIL_APP_PASS,
    },
    
    mercadoPago: {
      accessToken: process.env.MERCADO_PAGO_ACCESS_TOKEN,
      publicKey: process.env.MERCADO_PAGO_PUBLIC_KEY,
    }
  }
};

/**
 * 🎯 Detectar entorno automáticamente
 */
function detectEnvironment() {
  // Prioridad 1: Variable de entorno explícita
  if (process.env.NODE_ENV === 'production') {
    return 'production';
  }
  
  // Prioridad 2: Detectar por rama de Git (en CI/CD)
  const gitBranch = process.env.GITHUB_REF_NAME || process.env.GIT_BRANCH;
  if (gitBranch) {
    // Solo main va a producción, todo lo demás es development
    if (gitBranch === 'main') return 'production';
    return 'development'; // base, test, y cualquier otra rama
  }
  
  // Prioridad 3: Detectar por hostname en servidor
  const hostname = process.env.HOSTNAME;
  if (hostname && hostname.includes('prod')) {
    return 'production';
  }
  
  // Por defecto: development (local)
  return 'development';
}

// Obtener configuración actual
const currentEnv = detectEnvironment();
const config = environments[currentEnv];

// Validar configuración crítica en producción
if (currentEnv === 'production') {
  const required = ['MONGO_PROD_URI', 'ACCESS_TOKEN_SECRET'];
  const missing = required.filter(key => !process.env[key]);
  
  if (missing.length > 0) {
    console.error(`❌ Variables de entorno faltantes en producción: ${missing.join(', ')}`);
    console.log('💡 Usando configuraciones por defecto para desarrollo');
  }
}

// Log del entorno actual
console.log(`🌍 Entorno detectado: ${currentEnv.toUpperCase()}`);
console.log(`🚀 Aplicación: ${config.app.name}`);
console.log(`🔗 Base URL: ${config.app.baseUrl}`);
console.log(`🗄️  Base de datos: ${config.database.mongodb.replace(/\/\/.*:.*@/, '//***:***@')}`);

module.exports = {
  environment: currentEnv,
  config,
  ...config
};
