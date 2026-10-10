// Todo ajuste usa el flujo de solicitud y segunda autorización.
async function openStockAdjustment() { return openAdjustmentRequest(); }
document.querySelector('#new-button').addEventListener('click', () => {
  if (state.page === 'inventory') openStockAdjustment();
});
