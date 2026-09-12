import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { LibraryService } from '../services/library.service';

@Component({
  selector: 'app-library',
  templateUrl: './library.page.html',
  styleUrls: ['./library.page.scss'],
  standalone: false,
})
export class LibraryPage implements OnInit {
  myBooks: any[] = [];

  constructor(private libraryService: LibraryService, private router: Router) { }

  ngOnInit() {
    this.libraryService.getLibrary().subscribe(books => {
      this.myBooks = books;
    });
  }

  openDetail(book: any) {
    this.router.navigate(['/tabs/book-detail'], { state: { book } });
  }

  remove(bookId: number) {
    this.libraryService.removeBook(bookId).subscribe();
  }
}
