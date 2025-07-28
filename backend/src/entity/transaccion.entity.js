"use strict";
import { EntitySchema } from "typeorm";

const TransaccionSchema = new EntitySchema({
  name: "Transaccion",
  tableName: "transacciones",
  columns: {
    id: {
      type: "uuid",
      primary: true,
      generated: "uuid",
    },
    usuario_rut: {
      type: "varchar",
      length: 12,
      nullable: false,
    },
    tipo: {
      type: "enum",
      enum: ["pago", "cobro", "devolucion", "recarga"],
      nullable: false,
    },
    concepto: {
      type: "varchar",
      length: 500,
      nullable: false,
    },
    monto: {
      type: "decimal",
      precision: 10,
      scale: 2,
      nullable: false,
    },
    metodo_pago: {
      type: "enum",
      enum: ["saldo", "tarjeta", "efectivo"],
      nullable: false,
    },
    estado: {
      type: "enum",
      enum: ["completado", "pendiente", "cancelado"],
      nullable: false,
      default: "completado",
    },
    viaje_id: {
      type: "varchar",
      length: 24,
      nullable: true,
      comment: "ID del viaje asociado (si aplica)",
    },
    transaccion_id: {
      type: "varchar",
      length: 100,
      nullable: true,
      comment: "ID de transacción externa",
    },
    datos_adicionales: {
      type: "jsonb",
      nullable: true,
      comment: "Información adicional de la transacción",
    },
    fecha: {
      type: "timestamp with time zone",
      default: () => "CURRENT_TIMESTAMP",
      nullable: false,
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
  relations: {
    usuario: {
      target: "User",
      type: "many-to-one",
      joinColumn: {
        name: "usuario_rut",
        referencedColumnName: "rut",
      },
    },
  },
  indices: [
    {
      name: "IDX_TRANSACCION_USUARIO",
      columns: ["usuario_rut"],
    },
    {
      name: "IDX_TRANSACCION_TIPO",
      columns: ["tipo"],
    },
    {
      name: "IDX_TRANSACCION_FECHA",
      columns: ["fecha"],
    },
    {
      name: "IDX_TRANSACCION_VIAJE",
      columns: ["viaje_id"],
    },
  ],
});

export default TransaccionSchema;
