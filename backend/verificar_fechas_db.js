import mongoose from 'mongoose';
import moment from 'moment-timezone';

console.log('Conectando a MongoDB...');

const mongoUri = 'mongodb+srv://admin:root@biorutamongo.tphgmlc.mongodb.net/bioruta?retryWrites=true&w=majority';

mongoose.connect(mongoUri)
  .then(async () => {
    console.log('✅ Conectado a MongoDB');
    
    // Buscar el último viaje creado
    const db = mongoose.connection.db;
    const viajes = await db.collection('viajes').find({}).sort({ _id: -1 }).limit(3).toArray();
    
    if (viajes.length > 0) {
      console.log('\n=== ÚLTIMOS VIAJES EN DB ===');
      
      viajes.forEach((viaje, index) => {
        console.log(`\n--- Viaje ${index + 1} ---`);
        console.log('ID:', viaje._id);
        console.log('Usuario:', viaje.usuario_rut);
        console.log('Fecha ida (UTC almacenada):', viaje.fecha_ida.toISOString());
        
        // Convertir a hora de Chile para verificar
        const fechaChile = moment.tz(viaje.fecha_ida, 'America/Santiago');
        console.log('Fecha ida en Chile:', fechaChile.format('YYYY-MM-DD HH:mm:ss [Chile]'));
        console.log('Hora local Chile:', fechaChile.format('HH:mm'));
      });
    } else {
      console.log('No hay viajes en la base de datos');
    }
    
    mongoose.connection.close();
  })
  .catch(err => {
    console.error('Error:', err.message);
    mongoose.connection.close();
    process.exit(1);
  });
