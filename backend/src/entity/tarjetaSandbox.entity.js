"use strict";
import { EntitySchema } from "typeorm";

const TarjetaSandboxSchema = new EntitySchema({
  name: "TarjetaSandbox",
  tableName: "tarjetas_sandbox",
  columns: {
    id: {
      type: "int",
      primary: true,
      generated: true,
    },
    numero: {
      type: "varchar",
      length: 19,
      nullable: false,
      unique: true,
      comment: "Número de tarjeta (formato: XXXX-XXXX-XXXX-XXXX)",
    },
    nombreTitular: {
      type: "varchar",
      length: 255,
      nullable: false,
      comment: "Nombre del titular de la tarjeta",
    },
    fechaVencimiento: {
      type: "varchar",
      length: 7,
      nullable: false,
      comment: "Fecha de vencimiento (formato: MM/YYYY)",
    },
    cvv: {
      type: "varchar",
      length: 4,
      nullable: false,
      comment: "Código de verificación",
    },
    tipo: {
      type: "enum",
      enum: ["visa", "mastercard", "american_express"],
      nullable: false,
      comment: "Tipo de tarjeta",
    },
    banco: {
      type: "varchar",
      length: 100,
      nullable: false,
      comment: "Banco emisor",
    },
    limiteCredito: {
      type: "decimal",
      precision: 10,
      scale: 2,
      nullable: false,
      default: 50000,
      comment: "Límite de crédito disponible",
    },
    activa: {
      type: "boolean",
      nullable: false,
      default: true,
      comment: "Si la tarjeta está activa para uso",
    },
    createdAt: {
      type: "timestamp with time zone",
      default: () => "CURRENT_TIMESTAMP",
      nullable: false,
    },
  },
  indices: [
    {
      name: "IDX_TARJETA_NUMERO",
      columns: ["numero"],
      unique: true,
    },
    {
      name: "IDX_TARJETA_TIPO",
      columns: ["tipo"],
    },
  ],
});

export default TarjetaSandboxSchema;
