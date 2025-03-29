/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.{erb,html}',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js'
  ],
  theme: {
    extend: {
      colors: {
        'brand-orange': '#f15a24',
        'brand-blue': '#00658c',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      boxShadow: {
        'custom': '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
        'hover': '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)',
      }
    }
  },
  plugins: [
    require('@tailwindcss/aspect-ratio'),
  ],
  darkMode: 'class'
}
