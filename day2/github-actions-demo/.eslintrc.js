// 🔍 ESLint 설정 파일
// JavaScript 코드 품질을 검사합니다

module.exports = {
  // 환경 설정
  env: {
    node: true,
    es2022: true,
    jest: true
  },
  
  // 확장 설정
  extends: [
    'eslint:recommended'
  ],
  
  // 파서 옵션
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module'
  },
  
  // 규칙 설정
  rules: {
    // 에러 규칙
    'no-console': 'warn',
    'no-unused-vars': 'error',
    'no-undef': 'error',
    'no-unreachable': 'error',
    'no-duplicate-case': 'error',
    'no-empty': 'error',
    'no-extra-semi': 'error',
    'no-func-assign': 'error',
    'no-invalid-regexp': 'error',
    'no-irregular-whitespace': 'error',
    'no-obj-calls': 'error',
    'no-sparse-arrays': 'error',
    'no-unexpected-multiline': 'error',
    'no-unreachable': 'error',
    'use-isnan': 'error',
    'valid-typeof': 'error',
    
    // 경고 규칙
    'no-var': 'warn',
    'prefer-const': 'warn',
    'no-multiple-empty-lines': 'warn',
    'no-trailing-spaces': 'warn',
    'eol-last': 'warn',
    'comma-dangle': ['warn', 'never'],
    'quotes': ['warn', 'single'],
    'semi': ['warn', 'always'],
    'indent': ['warn', 2],
    'no-mixed-spaces-and-tabs': 'warn',
    'no-tabs': 'warn',
    'space-before-blocks': 'warn',
    'keyword-spacing': 'warn',
    'space-infix-ops': 'warn',
    'space-before-function-paren': ['warn', 'never'],
    'object-curly-spacing': ['warn', 'always'],
    'array-bracket-spacing': ['warn', 'never'],
    'comma-spacing': ['warn', { 'before': false, 'after': true }],
    'key-spacing': 'warn',
    'space-in-parens': ['warn', 'never'],
    'space-unary-ops': 'warn',
    'spaced-comment': ['warn', 'always'],
    'brace-style': ['warn', '1tbs'],
    'curly': ['warn', 'all'],
    'eqeqeq': ['warn', 'always'],
    'no-eval': 'warn',
    'no-implied-eval': 'warn',
    'no-new-func': 'warn',
    'no-script-url': 'warn',
    'no-sequences': 'warn',
    'no-throw-literal': 'warn',
    'no-unused-expressions': 'warn',
    'no-useless-call': 'warn',
    'no-useless-concat': 'warn',
    'radix': 'warn',
    'wrap-iife': ['warn', 'any'],
    'yoda': 'warn'
  },
  
  // 무시할 파일/디렉토리
  ignorePatterns: [
    'node_modules/',
    'coverage/',
    'dist/',
    'build/',
    '*.min.js'
  ]
};
