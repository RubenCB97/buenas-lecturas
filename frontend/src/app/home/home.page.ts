import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { BooksService } from '../services/books.service';
import { LibraryService } from '../services/library.service';
import { ToastController } from '@ionic/angular';

@Component({
  selector: 'app-home',
  templateUrl: 'home.page.html',
  styleUrls: ['home.page.scss'],
  standalone: false,
})
export class HomePage implements OnInit {
  user: any;
  trendingBooks: any[] = [];
  recommendedBooks: any[] = [];
  searchQuery: string = '';
  myLibrary: any[] = [];

  constructor(
    private authService: AuthService,
    private booksService: BooksService,
    private libraryService: LibraryService,
    private toastCtrl: ToastController,
    private router: Router
  ) {}

  openDetail(book: any) {
    this.router.navigate(['/tabs/book-detail'], { state: { book } });
  }

  ngOnInit() {
    this.authService.currentUser$.subscribe(user => {
      this.user = user;
    });
    this.loadInitialBooks();
    this.refreshLibrary();
  }

  loadInitialBooks() {
    this.booksService.searchBooks('bestsellers 2024').subscribe(books => {
      this.trendingBooks = books.slice(0, 10);
      this.recommendedBooks = books.slice(10, 20);
    });
  }

  onSearch(event: any) {
    const query = event.target.value;
    if (query && query.trim() !== '') {
      this.booksService.searchBooks(query).subscribe(books => {
        this.recommendedBooks = books;
      });
    } else {
      this.loadInitialBooks();
    }
  }

  refreshLibrary() {
    this.libraryService.getLibrary().subscribe(lib => {
      this.myLibrary = lib;
    });
  }

  isInLibrary(book: any): boolean {
    const id = book.googleId;
    return this.myLibrary.some(b => b.googleId === id || b.book?.googleId === id);
  }

  toggleLibrary(book: any) {
    if (this.isInLibrary(book)) {
      const bookInLib = this.myLibrary.find(b => b.googleId === book.googleId || b.book?.googleId === book.googleId);
      console.log('Book found in library for removal:', bookInLib);
      const id = bookInLib.book?.id || bookInLib.id;
      console.log('Using ID for removal:', id);
      this.libraryService.removeBook(id).subscribe(() => {
        this.refreshLibrary();
      });
    } else {
      this.libraryService.addBook(book).subscribe(() => {
        this.refreshLibrary();
      });
    }
  }
}
