"use strict";
import { EntitySchema } from "typeorm";

const UserSchema = new EntitySchema({
  name: "User",
  tableName: "users",
  columns: {
    rut: {
      type: "varchar",
      length: 12,
      primary: true,
      nullable: false,
      unique: true,
    },
    nombreCompleto: {
      type: "varchar",
      length: 255,
      nullable: false,
    },
    fechaNacimiento: {
      type: "date",
      nullable: true,
    },
    genero: {
      type: "enum",
      enum: ["masculino", "femenino", "no_binario", "prefiero_no_decir"],
      nullable: false,
    },
    carrera: {
      type: "varchar",
      length: 100,
      nullable: true,
    },
    altura: {
      type: "int",
      nullable: true,
    },
    Peso: {
      type: "int",
      nullable: true,
    },
    descripcion: {
      type: "text",
      nullable: true,
    },
    clasificacion: {
      type: "float",
      nullable: true,
    },
    cantidadValoraciones: {
      type: "int",
      nullable: false,
      default: 0,
      comment: "Número total de valoraciones recibidas por este usuario",
    },
    puntuacion: {
      type: "int",
      nullable: true,
    },
    contadorReportes: {
      type: "int",
      nullable: false,
      default: 0,
      comment: "Número total de reportes recibidos por este usuario",
    },
    email: {
      type: "varchar",
      length: 255,
      nullable: false,
      unique: true,
    },
    rol: {
      type: "varchar",
      length: 50,
      nullable: false,
    },
    password: {
      type: "varchar",
      nullable: false,
    },
    fcmToken: {
      type: "text",
      nullable: true,
      comment: "Token FCM para notificaciones push",
    },
    saldo: {
      type: "decimal",
      precision: 10,
      scale: 2,
      nullable: false,
      default: 0,
      comment: "Saldo disponible del usuario para pagos",
    },
    tarjetas: {
      type: "jsonb",
      nullable: true,
      comment: "Lista de tarjetas agregadas por el usuario",
    },
    createdAt: {
      type: "timestamp with time zone",
      default: () => "CURRENT_TIMESTAMP",
      nullable: false,
    },
    updatedAt: {
      type: "timestamp with time zone",
      default: () => "CURRENT_TIMESTAMP",
      onUpdate: "CURRENT_TIMESTAMP",
      nullable: false,
    },
  },
  indices: [
    {
      name: "IDX_USER_RUT",
      columns: ["rut"],
      unique: true,
    },
    {
      name: "IDX_USER_EMAIL",
      columns: ["email"],
      unique: true,
    },
  ],
});

export default UserSchema;