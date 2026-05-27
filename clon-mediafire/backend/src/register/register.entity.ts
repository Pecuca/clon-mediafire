import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, CreateDateColumn } from 'typeorm';
import { Archive } from '../archive/archive.entity';

@Entity('register')
export class Register {
  @PrimaryGeneratedColumn()
  register_id!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  register_date!: Date;

  @Column({ type: 'varchar', length: 100, nullable: true })
  register_type_na!: string | null;

  @Column()
  register_type_id!: number;

  @Column({ type: 'int', nullable: true })
  user_id?: number | null;

  @Column({ type: 'int', nullable: true })
  archive_id?: number | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  archive_na?: string | null;

  @Column({ type: 'text', nullable: true })
  details?: string | null;

  @Column({ type: 'varchar', length: 45, nullable: true })
  ip_address?: string | null;

  @Column({ default: true })
  success!: boolean;

  @ManyToOne(() => Archive, archive => (archive as any).registers, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'archive_id' })
  archive?: Archive | null;
}
