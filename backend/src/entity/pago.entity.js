"use strict";
import { EntitySchema } from "typeorm";

const PagoSchema = new EntitySchema({
  name: "Pago",
  tableName: "pagos",
  columns: {
    id: {
      primary: true,
      type: "int",
      generated: true,
    },
    viajeId: {
      type: "varchar",
      length: 50,
      nullable: false,
      comment: "ID del viaje en MongoDB",
    },
    usuarioId: {
      type: "varchar",
      length: 12,
      nullable: false,
      comment: "RUT del usuario que realiza el pago",
    },
    montoTotal: {
      type: "decimal",
      precision: 10,
      scale: 2,
      nullable: false,
    },
    estado: {
      type: "varchar",
      length: 50,
      default: "pendiente",
      comment: "Estados: pendiente, aprobado, rechazado, cancelado",
    },
    mercadoPagoId: {
      type: "varchar",
      length: 100,
      nullable: true,
      comment: "ID de la preferencia o pago en MercadoPago",
    },
    metodoPago: {
      type: "varchar",
      length: 50,
      nullable: true,
      comment: "Método de pago utilizado",
    },
    fechaCreacion: {
      type: "timestamp",
      default: () => "CURRENT_TIMESTAMP",
    },
    fechaActualizacion: {
      type: "timestamp",
      default: () => "CURRENT_TIMESTAMP",
      onUpdate: "CURRENT_TIMESTAMP",
    },
    descripcion: {
      type: "text",
      nullable: true,
    },
    datosRespuesta: {
      type: "text",
      nullable: true,
      comment: "JSON con la respuesta completa de MercadoPago",
    },
  },
  relations: {
    usuario: {
      target: "User",
      type: "many-to-one",
      joinColumn: {
        name: "usuarioId",
      },
    },
  },
  indices: [
    {
      name: "IDX_PAGO_VIAJE",
      columns: ["viajeId"],
    },
    {
      name: "IDX_PAGO_USUARIO",
      columns: ["usuarioId"],
    },
    {
      name: "IDX_PAGO_MERCADOPAGO",
      columns: ["mercadoPagoId"],
    },
  ],
});

export default PagoSchema;
