const { Server } = require("socket.io");
const chatService = require("./chatService");

let io;  // Variable para la instancia de Socket.IO

function initializeSocket(server) {
  io = new Server(server, {
    cors: {
      origin: "*",  // Permite solicitudes de cualquier origen
      methods: ["GET", "POST"],  // Métodos permitidos
    }
  });

  io.on("connection", (socket) => {
    console.log(`Usuario conectado: ${socket.id}`);

    // Cuando un usuario envía un mensaje
    socket.on("send_message", async (data) => {
      try {
        const savedMessage = await chatService.saveMessage(data);

        // Emitir el mensaje solo al destinatario
        const { receiverId } = data;
        io.to(receiverId).emit("receive_message", savedMessage);  // Enviar solo al usuario receptor

      } catch (err) {
        console.error("Error al guardar mensaje:", err);
      }
    });

    // Desconexión del usuario
    socket.on("disconnect", () => {
      console.log(`Usuario desconectado: ${socket.id}`);
    });
  });
}

// Función para obtener la instancia de 'io'
function getIO() {
  if (!io) {
    throw new Error("Socket.io no ha sido inicializado.");
  }
  return io;
}

module.exports = {
  initializeSocket,
  getIO,
};
