import { Entity, PrimaryGeneratedColumn, Column, OneToMany, CreateDateColumn } from 'typeorm';
import { Directory } from '../directory/directory.entity';

@Entity('user')
export class User {
  @PrimaryGeneratedColumn()
  user_id!: number;

  @Column()
  user_na!: string;

  @Column({ unique: true })
  user_mail!: string;

  @Column()
  user_pass!: string;

  @OneToMany(() => Directory, directory => directory.user)
  directories!: Directory[];
  
  @CreateDateColumn()
  created_at!: Date;
  @Column({ type: 'varchar', nullable: true })
  reset_token?: string | null;

  @Column({ type: 'timestamp', nullable: true })
  reset_token_expires?: Date | null;
}
