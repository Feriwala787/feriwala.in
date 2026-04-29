/**
 * Send a 500 response without leaking internal error details in production.
 * Use this in every route catch block instead of `res.status(500).json({ message: error.message })`.
 */
function routeError(res, error) {
  console.error(error);
  const message = process.env.NODE_ENV === 'production'
    ? 'Internal Server Error'
    : (error.message || 'Internal Server Error');
  return res.status(500).json({ success: false, message });
}

module.exports = { routeError };
