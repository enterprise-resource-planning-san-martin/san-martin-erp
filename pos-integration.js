/* Helper for a POS client using the same Supabase session and configured db client. */
window.SanMartinPOS = {
  registrarVenta: async ({ ubicacionId, items, numero = null, observaciones = null }) => {
    return db.rpc('registrar_venta_pos', {
      p_ubicacion_id: ubicacionId,
      p_items: items.map(item => ({ producto_id:item.productoId, cantidad:item.cantidad, precio_unitario:item.precioUnitario ?? null })),
      p_numero: numero,
      p_observaciones: observaciones
    });
  }
};
