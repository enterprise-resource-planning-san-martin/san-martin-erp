/* Call these only from your authenticated e-commerce backend or Edge Function. */
window.SanMartinEcommerce = {
  reservar: ({ ubicacionId, items, numero = null, observaciones = null, minutosExpiracion = 30 }) => db.rpc('reservar_stock_ecommerce', {
    p_ubicacion_id:ubicacionId,p_items:items.map(x=>({producto_id:x.productoId,cantidad:x.cantidad,precio_unitario:x.precioUnitario??null})),p_numero:numero,p_observaciones:observaciones,p_minutos_expiracion:minutosExpiracion
  }),
  confirmarPago: pedidoId => db.rpc('confirmar_pago_ecommerce',{p_pedido_id:pedidoId}),
  cancelar: (pedidoId,motivo=null) => db.rpc('cancelar_pedido_ecommerce',{p_pedido_id:pedidoId,p_motivo:motivo}),
  liberarExpiradas: () => db.rpc('liberar_reservas_expiradas')
};
