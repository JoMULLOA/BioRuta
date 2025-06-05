const { Server } = require("socket.io");
const chatService = require("./chatService");

let io;

function initializeSocket(server) {
  io = new Server(server, {
    cors: {
      origin: "*",
      methods: ["GET", "POST"]
    }
  });

  io.on("connection", (socket) => {
    console.log(`Usuario conectado: ${socket.id}`);

    socket.on("send_message", async (data) => {
      try {
        const savedMessage = await chatService.saveMessage(data);
        io.emit("receive_message", savedMessage);
      } catch (err) {
        console.error("Error al guardar mensaje:", err);
      }
    });

    socket.on("disconnect", () => {
      console.log(`Usuario desconectado: ${socket.id}`);
    });
  });
}

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