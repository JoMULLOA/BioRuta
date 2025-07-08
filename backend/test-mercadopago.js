import { MercadoPagoConfig, Preference } from 'mercadopago';

// Configurar MercadoPago
const client = new MercadoPagoConfig({
  accessToken: 'TEST-5373276182271282-062000-37c5afda07e978bac40128ad19b5d93a-203834388',
});

const preference = new Preference(client);

// Test simple
async function testMercadoPago() {
  try {
    console.log('🧪 Probando MercadoPago...');
    
    const preferenceData = {
      items: [
        {
          title: 'Prueba de conexión',
          quantity: 1,
          unit_price: 1000,
          currency_id: 'CLP',
        }
      ],
      external_reference: 'test_123',
    };

    console.log('📦 Enviando preferencia:', JSON.stringify(preferenceData, null, 2));
    
    const result = await preference.create({ body: preferenceData });
    
    console.log('✅ Resultado exitoso:', result);
    return result;
  } catch (error) {
    console.error('❌ Error:', error);
    console.error('❌ Error message:', error.message);
    console.error('❌ Error cause:', error.cause);
    throw error;
  }
}

testMercadoPago().then(result => {
  console.log('✅ Test completado exitosamente');
  process.exit(0);
}).catch(error => {
  console.error('❌ Test falló');
  process.exit(1);
});
