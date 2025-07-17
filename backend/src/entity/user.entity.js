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
    puntuacion: {
      type: "int",
      nullable: true,
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
    genero: {
      type: "enum",
      enum: ["masculino", "femenino", "no_binario", "prefiero_no_decir"],
      nullable: true,
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