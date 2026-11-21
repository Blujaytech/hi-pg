import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#F84464',
          pressed: '#E0304F',
          soft: '#FFE8ED',
          text: '#C0183A',
        },
        ink: {
          DEFAULT: '#333545',
          soft: '#454759',
        },
        canvas: '#F5F5F5',
        line: '#D6D6DC',
        success: '#0F7A55',
        warning: '#9A5A00',
        danger: '#D93636',
      },
      borderRadius: {
        card: '1rem',
        panel: '1.5rem',
      },
      boxShadow: {
        card: '0 10px 30px rgba(51, 53, 69, 0.07)',
        floating: '0 20px 50px rgba(51, 53, 69, 0.16)',
      },
      maxWidth: {
        content: '75rem',
      },
    },
  },
  plugins: [],
};

export default config;
