import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { LibraryService } from '../services/library.service';

@Component({
  selector: 'app-book-detail',
  templateUrl: './book-detail.page.html',
  styleUrls: ['./book-detail.page.scss'],
  standalone: false,
})
export class BookDetailPage implements OnInit {
  book: any;
  status: string = 'WANT_TO_READ';
  isInLibrary: boolean = false;
  rating: number = 0;

  constructor(
    private route: ActivatedRoute, 
    private libraryService: LibraryService,
    private router: Router
  ) { }

  ngOnInit() {}

  ionViewWillEnter() {
    this.book = history.state.book;
    
    if (!this.book) {
      const id = this.route.snapshot.paramMap.get('id');
      if (id) {
        this.libraryService.getBookById(id).subscribe((data: any) => {
          this.book = data;
          this.checkLibraryStatus();
        });
      }
    } else {
      this.checkLibraryStatus();
    }
  }

  checkLibraryStatus() {
    this.libraryService.getLibrary().subscribe(library => {
      const id = this.book.googleId || this.book.book?.googleId;
      const foundBook = library.find(b => (b.googleId === id || b.book?.googleId === id));
      this.isInLibrary = !!foundBook;
      if (foundBook) {
        this.status = foundBook.status;
        this.rating = foundBook.rating || 0;
      }
    });
  }

  toggleLibrary() {
    if (this.isInLibrary) {
      const id = this.book.book ? this.book.book.id : this.book.id;
      this.libraryService.removeBook(id).subscribe(() => {
        this.isInLibrary = false;
        this.router.navigate(['/tabs/library']);
      });
    } else {
      this.libraryService.addBook(this.book).subscribe(() => {
        this.isInLibrary = true;
      });
    }
  }

  updateStatus() {
    const id = this.book.book ? this.book.book.id : this.book.id;
    this.libraryService.updateStatus(id, this.status).subscribe();
  }

  setRating(rating: number) {
    this.rating = rating;
    // Si el objeto libro ya tiene un ID en la biblioteca (this.book.id), lo usamos. 
    // Si no, intentamos buscar el ID dentro del objeto 'book' anidado,
    // o si el libro viene de búsqueda, podría ser directamente this.book.id
    const id = this.book.book?.id || this.book.id;
    
    if (id) {
      this.libraryService.updateRating(id, rating).subscribe();
    } else {
      console.error('No se pudo encontrar un ID de libro válido para realizar el rating.');
    }
  }
}
