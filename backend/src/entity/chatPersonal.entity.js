// src/entity/chatPersonal.entity.js
import { EntitySchema } from "typeorm";
import User from "./user.entity.js";

export default new EntitySchema({
  name: "ChatPersonal",
  tableName: "chats_personales",
  columns: {
    id: {
      primary: true,
      type: "int",
      generated: true,
    },
    // Identificador único para la conversación (ej: "12345678-87654321")
    identificadorChat: {
      type: "varchar",
      length: 50,
      unique: true,
      nullable: false,
    },
    // RUT del usuario 1 de la conversación
    rutUsuario1: {
      type: "varchar",
      length: 12,
      nullable: false,
    },
    // RUT del usuario 2 de la conversación
    rutUsuario2: {
      type: "varchar",
      length: 12,
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
  relations: {
    // Usuario 1 de la conversación
    usuario1: {
      type: "many-to-one",
      target: User,
      joinColumn: {
        name: "rutUsuario1",
        referencedColumnName: "rut",
      },
      eager: true,
    },
    // Usuario 2 de la conversación
    usuario2: {
      type: "many-to-one",
      target: User,
      joinColumn: {
        name: "rutUsuario2",
        referencedColumnName: "rut",
      },
      eager: true,
    },
  },
  indices: [
    {
      name: "IDX_CHAT_PERSONAL_IDENTIFICADOR",
      columns: ["identificadorChat"],
      unique: true,
    },
    {
      name: "IDX_CHAT_PERSONAL_USUARIO1",
      columns: ["rutUsuario1"],
    },
    {
      name: "IDX_CHAT_PERSONAL_USUARIO2",
      columns: ["rutUsuario2"],
    },
    {
      name: "IDX_CHAT_PERSONAL_FECHA_ACTUALIZACION",
      columns: ["fechaUltimaActualizacion"],
    },
  ],
});
