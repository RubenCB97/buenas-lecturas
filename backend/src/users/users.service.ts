import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  async findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { email } });
  }

  async findByGoogleId(googleId: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { googleId } });
  }

  async create(userData: Partial<User>): Promise<User> {
    const newUser = this.usersRepository.create(userData);
    return this.usersRepository.save(newUser);
  }

  async findOrCreateDevUser(
    email = 'ruben@buenaslecturas.app',
    firstName = 'Rubén',
    lastName = 'García',
  ): Promise<User> {
    let user = await this.usersRepository.findOne({ where: { email } });
    if (!user) {
      user = this.usersRepository.create({
        googleId: 'dev_user_001',
        email,
        firstName,
        lastName,
      });
      user = await this.usersRepository.save(user);
    }
    return user;
  }

  async getProfile(userId: number): Promise<User> {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async updateProfile(userId: number, updateData: Partial<User>): Promise<User> {
    const user = await this.getProfile(userId);
    // Ignoramos claves con `undefined` para no borrar campos sin querer, pero
    // permitimos `null` explícito (p. ej. al quitar el avatar).
    for (const [key, value] of Object.entries(updateData)) {
      if (value !== undefined) {
        (user as any)[key] = value;
      }
    }
    return this.usersRepository.save(user);
  }
}
