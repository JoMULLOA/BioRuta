// src/entity/chatGrupal.entity.js
import { EntitySchema } from "typeorm";

export default new EntitySchema({
  name: "ChatGrupal",
  tableName: "chats_grupales",
  columns: {
    id: {
      primary: true,
      type: "int",
      generated: true,
    },
    // ID del viaje en MongoDB
    idViajeMongo: {
      type: "varchar",
      length: 24,
      unique: true,
      nullable: false,
    },
    // Chat completo guardado como JSON
    chatCompleto: {
      type: "json",
      nullable: false,
      default: () => "'[]'", // Array vacío por defecto
    },
    // Último mensaje para mostrar en lista de chats
    ultimoMensaje: {
      type: "text",
      nullable: true,
    },
    // Fecha del último mensaje
    fechaUltimoMensaje: {
      type: "timestamp",
      nullable: true,
    },
    // Total de mensajes en el chat
    totalMensajes: {
      type: "int",
      default: 0,
    },
    // RUT del conductor (para referencia rápida)
    rutConductor: {
      type: "varchar",
      length: 12,
      nullable: false,
    },
    // Lista de participantes del viaje (JSON)
    participantes: {
      type: "json",
      nullable: false,
      default: () => "'[]'", // Array de RUTs
    },
    // Estado del chat grupal
    estadoChat: {
      type: "enum",
      enum: ["activo", "finalizado", "cancelado"],
      default: "activo",
    },
    // Fecha de creación del chat
    fechaCreacion: {
      type: "timestamp",
      default: () => "CURRENT_TIMESTAMP",
    },
    // Última vez que se actualizó
    fechaUltimaActualizacion: {
      type: "timestamp",
      default: () => "CURRENT_TIMESTAMP",
    },
    // Para soft delete
    eliminado: {
      type: "boolean",
      default: false,
    },
  },
  indices: [
    {
      name: "IDX_CHAT_GRUPAL_VIAJE",
      columns: ["idViajeMongo"],
      unique: true,
    },
    {
      name: "IDX_CHAT_GRUPAL_CONDUCTOR",
      columns: ["rutConductor"],
    },
    {
      name: "IDX_CHAT_GRUPAL_ESTADO",
      columns: ["estadoChat"],
    },
    {
      name: "IDX_CHAT_GRUPAL_FECHA_ACTUALIZACION",
      columns: ["fechaUltimaActualizacion"],
    },
  ],
});
