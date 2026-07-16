
const CurrencyRate = require('../models/model_CurrencyRate');
// الحصول على راتب التحويل
async function getExchangeRate() {
  try {
    const rate = await CurrencyRate.findOne({ baseCurrency: 'USD', targetCurrency: 'SYP' });
    return rate?.rate || 0;
  } catch (error) {
    console.error('Error fetching exchange rate:', error);
    return 0;
  }
}

// تحويل المبلغ من مبلغ إلى مبلغ آخر
async function convertPrice(amount, fromCurrency, toCurrency) {
  if (fromCurrency === toCurrency) return amount;

  const rate = await getExchangeRate();
  if (rate === 0) return amount;

  if (fromCurrency === 'USD' && toCurrency === 'SYP') {
    return amount * rate;
  }
  if (fromCurrency === 'SYP' && toCurrency === 'USD') {
    return amount / rate;
  }
  return amount;
}

// تنسيق المبلغ من مبلغ إلى مبلغ آخر
function formatDualPrice(amount, baseCurrency, rate) {
  if (!rate || rate === 0) return `${amount} ${baseCurrency}`;

  if (baseCurrency === 'USD') {
    const converted = amount * rate;
    return `${amount} USD (${converted.toLocaleString()} SYP)`;
  }
  const converted = amount / rate;
  return `${amount.toLocaleString()} SYP (${converted.toFixed(2)} USD)`;
}

module.exports = { getExchangeRate, convertPrice, formatDualPrice };
