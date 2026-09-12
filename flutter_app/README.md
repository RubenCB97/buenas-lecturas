# 📚 BuenasLecturas (Flutter App)

Una aplicación móvil y web multiplataforma para lectores apasionados, inspirada en la funcionalidad de **Goodreads (Amazon)** pero con una **estética editorial moderna, limpia y de alto rendimiento**, construida íntegramente en **Flutter** y conectada al backend **NestJS**.

---

## ✨ Características y Mejoras estilo Goodreads

1. **🎨 Estética Editorial & Diseño Premium**:
   - Paleta de tonos cálidos inspirada en literatura: Papel cálido (`#F9F6F0`), Terracota (`#C8602E`), Verde biblioteca (`#2D5A43`), Ámbar estrella (`#F59E0B`) y Modo Oscuro profundo (`#12100E`).
   - Tipografía refinada con Google Fonts (*Playfair Display* para títulos literarios y *Plus Jakarta Sans* para interfaz).
   - Animaciones *Hero* fluidas de portadas al entrar en detalles.

2. **🔍 Explorar & Descubrimiento**:
   - **Tarjeta de lectura en curso**: Muestra el libro que estás leyendo actualmente con barra de porcentaje y páginas leídas.
   - **Carrusel de Tendencias literarias**: Acceso directo a los libros más leídos.
   - **Filtro por Categorías / Géneros**: Chips para filtrar recomendaciones (Ciencia Ficción, Fantasía, Clásicos, Filosofía, etc.).
   - **Búsqueda en tiempo real**: Conectada a la API de búsqueda con *debouncing* automático.

3. **📖 Ficha del Libro (Book Detail)**:
   - Portada en alta resolución con sombra suave.
   - Botón de estado de lectura interactivo (*Action Sheet*): "Quiero leer", "Leyendo", "Leído".
   - **Desglose de calificaciones de Goodreads**: Gráfico con distribución de porcentajes de 5★ a 1★.
   - Puntuación interactiva de 1 a 5 estrellas.
   - Sinopsis expandible (*Leer más* / *Leer menos*).
   - Ficha técnica completa (Editorial, Fecha, Idioma, Géneros, ISBN, ASIN, Premios).
   - **Reseñas de la comunidad**: Listado de opiniones de lectores y modal para redactar tu propia reseña.

4. **📚 Mi Biblioteca & Estanterías (*Shelves*)**:
   - Pestañas organizadas: *Todos*, *Leyendo*, *Por leer* y *Leídos*.
   - **Alternador de vista**: Lista detallada con barras de progreso vs. Cuadrícula de portadas (*Grid*).
   - Ordenación por fecha de adición, título o puntuación.
   - Búsqueda y filtrado dentro de la propia biblioteca.
   - Deslizar (*Swipe*) para eliminar libros con diálogo de confirmación.

5. **💬 Comunidad & Actividad**:
   - Timeline social de lecturas, valoraciones y nuevas reseñas añadidas.

6. **👤 Perfil & Reto de Lectura**:
   - **Reto de Lectura Anual**: Contador y barra de progreso hacia tu meta de libros del año.
   - Estadísticas rápidas: Total de libros, libros leídos y páginas totales leídas.
   - Etiquetas de géneros favoritos.
   - Editor de perfil in-app (Nombre, biografía y géneros).

---

## 🏛️ Estructura del Código

```
flutter_app/
├── lib/
│   ├── main.dart                      # Configuración de tema, Provider y arranque
│   ├── core/
│   │   ├── constants/api_constants.dart # Endpoints del backend NestJS
│   │   ├── network/api_client.dart    # Cliente HTTP con tokens JWT e interceptores
│   │   ├── theme/app_theme.dart       # Colores, tipografías y sombras
│   │   └── utils/date_formatter.dart  # Formateador de fechas relativas
│   ├── models/
│   │   ├── book_model.dart            # Modelo de Libro y parsing de Google Books
│   │   ├── user_book_model.dart       # Libro de usuario, estados y progreso
│   │   ├── review_model.dart          # Reseñas de la comunidad
│   │   ├── activity_model.dart        # Feed de actividad
│   │   └── user_model.dart            # Datos de perfil de usuario
│   ├── providers/
│   │   ├── auth_provider.dart         # Autenticación, sesión y demo user
│   │   ├── library_provider.dart      # Gestión de estanterías y filtros
│   │   ├── explore_provider.dart      # Búsqueda, tendencias y categorías
│   │   ├── book_detail_provider.dart  # Reseñas y desglose de calificaciones
│   │   └── profile_provider.dart      # Actividades y estadísticas
│   ├── widgets/
│   │   ├── book_card.dart             # Tarjeta con 4 estilos (Mini, Feed, Fila, Grid)
│   │   ├── book_cover_image.dart      # Portada con caché, shimmer y placeholder
│   │   ├── rating_stars.dart          # Estrellas de valoración interactivas
│   │   ├── reading_progress_bar.dart  # Barra de progreso con páginas y %
│   │   ├── rating_breakdown.dart      # Gráfico de barras de calificaciones estilo Goodreads
│   │   ├── status_badge.dart          # Badge para estados de lectura
│   │   └── custom_search_bar.dart     # Barra de búsqueda con autocompletado
│   └── screens/
│       ├── main_navigation_screen.dart # Barra de navegación inferior
│       ├── explore/explore_screen.dart # Pantalla principal de descubrimiento
│       ├── book_detail/book_detail_screen.dart # Ficha del libro
│       ├── book_detail/write_review_sheet.dart # Modal para redactar reseña
│       ├── library/library_screen.dart # Estanterías de la biblioteca
│       ├── activity/activity_screen.dart # Feed de la comunidad
│       ├── profile/profile_screen.dart # Perfil de usuario y estadísticas
│       ├── profile/edit_profile_sheet.dart # Modal para editar perfil
│       └── auth/login_screen.dart     # Pantalla de bienvenida y login
└── pubspec.yaml                       # Dependencias del proyecto
```

---

## 🚀 Cómo ejecutar la aplicación

### 1. Iniciar el Backend (NestJS)
Desde la raíz del proyecto:
```bash
cd backend
npm install
npm run start:dev
```
El backend se levantará en `http://localhost:3000`.

### 2. Ejecutar la App Flutter
Desde la carpeta `flutter_app`:
```bash
cd flutter_app
flutter pub get
```

Para probar en el navegador web:
```bash
flutter run -d chrome
```

Para probar en emulador iOS o Android:
```bash
flutter run
```
*(En emulador Android, `ApiClient` se conecta automáticamente a `http://10.0.2.2:3000`)*.
